import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/document/document_text_service.dart';
import '../../../core/ocr/ocr_service.dart';
import '../../../core/storage/media_store.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/client_model.dart';
import '../../providers/client_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/camera_capture_dialog.dart';

enum ClientFormMode { manual, ocr }

class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({
    super.key,
    this.client,
    this.initialMode = ClientFormMode.manual,
  });

  final ClientModel? client;
  final ClientFormMode initialMode;

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _cinController;
  late final TextEditingController _licenseNumberController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  File? _cinImageFile;
  File? _licenseImageFile;

  bool _isSubmitting = false;
  bool _isLoadingOcr = false;
  String? _pageError;

  String _humanizeError(Object e) {
    final raw = e.toString();
    // Most thrown Exceptions become "Exception: message"
    final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    return msg.trim().isEmpty ? 'Une erreur est survenue.' : msg.trim();
  }

  final DocumentTextService _documentTextService = DocumentTextService.instance;
  final OcrService _ocrService = OcrService();
  static const _imageExtensions = ['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'];
  static const _tmpPrefix = 'carrent_import_';

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _firstNameController = TextEditingController(text: c?.firstName ?? '');
    _lastNameController = TextEditingController(text: c?.lastName ?? '');
    _cinController = TextEditingController(text: c?.cin ?? '');
    _licenseNumberController =
        TextEditingController(text: c?.licenseNumber ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cinController.dispose();
    _licenseNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<File?> _pickImageFromCamera(ImageSource source) async {
    if (Platform.isMacOS || Platform.isWindows) {
      // Use custom camera dialog for desktop
      final result = await showDialog<File?>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const CameraCaptureDialog(),
      );
      return result;
    }

    // Standard image_picker for mobile
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 95,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caméra non disponible. Sélection depuis les fichiers.'),
          ),
        );
      }
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return null;
      return File(picked.path);
    }
  }

  void _showImportSourceSheet({
    required String title,
    required void Function(File file) onFileReady,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Importer depuis l\'appareil'),
                subtitle: const Text('Fichier image, PDF ou Word'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final file = await _pickDocumentAsReadableFile();
                  if (file == null || !mounted) return;
                  onFileReady(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Utiliser la caméra'),
                subtitle: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final file = await _pickImageFromCamera(ImageSource.camera);
                  if (file == null || !mounted) return;
                  onFileReady(file);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importCin() async {
    if (_isLoadingOcr) return;
    _showImportSourceSheet(
      title: 'Importer CIN',
      onFileReady: (file) async {
        final ext = file.path.split('.').last.toLowerCase();
        if (_imageExtensions.contains(ext)) {
          setState(() => _cinImageFile = file);
        }
        await _runOcrOnCinFile(file);
      },
    );
  }

  Future<void> _importPermis() async {
    if (_isLoadingOcr) return;
    _showImportSourceSheet(
      title: 'Importer Permis',
      onFileReady: (file) async {
        final ext = file.path.split('.').last.toLowerCase();
        if (_imageExtensions.contains(ext)) {
          setState(() => _licenseImageFile = file);
        }
        await _runOcrOnLicenseFile(file);
      },
    );
  }

  Future<File?> _pickDocumentAsReadableFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _documentTextService.allowedExtensions,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;

    // On macOS sandbox, prefer bytes (path may not be readable).
    final bytes = picked.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      final ext = (picked.extension ?? '').isNotEmpty
          ? picked.extension!
          : (picked.name.contains('.') ? picked.name.split('.').last : 'bin');
      final tmp = File(
        '${Directory.systemTemp.path}/$_tmpPrefix${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await tmp.writeAsBytes(bytes, flush: true);
      return tmp;
    }

    final path = picked.path;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file;
  }

  Future<void> _runOcrOnCinFile(File file) async {
    setState(() => _isLoadingOcr = true);
    try {
      final text = await _ocrService.extractText(file.path);
      if (text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Aucun texte extrait. Essayez une image plus nette ou un autre fichier.',
              ),
            ),
          );
        }
        return;
      }
      final data = _ocrService.parseCINData(text);
      final hasData = (data['firstName'] ?? '').isNotEmpty ||
          (data['lastName'] ?? '').isNotEmpty ||
          (data['cin'] ?? '').isNotEmpty;
      if (mounted) {
        setState(() {
          if ((data['firstName'] ?? '').isNotEmpty) _firstNameController.text = data['firstName']!;
          if ((data['lastName'] ?? '').isNotEmpty) _lastNameController.text = data['lastName']!;
          if ((data['cin'] ?? '').isNotEmpty) _cinController.text = data['cin']!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasData
                ? 'Informations extraites avec succès.'
                : 'Texte extrait mais format CIN non reconnu. Vérifiez et complétez.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur extraction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingOcr = false);
    }
  }

  Future<void> _runOcrOnLicenseFile(File file) async {
    setState(() => _isLoadingOcr = true);
    try {
      final text = await _ocrService.extractText(file.path);
      if (text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Aucun texte extrait. Essayez une image plus nette ou un autre fichier.',
              ),
            ),
          );
        }
        return;
      }
      final data = _ocrService.parseLicenseData(text);
      final hasData = (data['licenseNumber'] ?? '').isNotEmpty ||
          (data['firstName'] ?? '').isNotEmpty ||
          (data['lastName'] ?? '').isNotEmpty;
      if (mounted) {
        setState(() {
          if ((data['licenseNumber'] ?? '').isNotEmpty) {
            _licenseNumberController.text = data['licenseNumber']!;
          }
          if ((data['firstName'] ?? '').isNotEmpty && _firstNameController.text.trim().isEmpty) {
            _firstNameController.text = data['firstName']!;
          }
          if ((data['lastName'] ?? '').isNotEmpty && _lastNameController.text.trim().isEmpty) {
            _lastNameController.text = data['lastName']!;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasData
                ? 'Informations extraites avec succès.'
                : 'Texte extrait mais format permis non reconnu. Vérifiez et complétez.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur extraction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingOcr = false);
    }
  }

  /// Thumbnail for an attachment: the file just picked if there is one, else
  /// whatever is on the saved client. [stored] goes through the media store
  /// because it holds a file name, not a path, and may point at nothing if the
  /// picture was lost by the older build.
  Widget _attachmentPreview({
    required File? picked,
    required String? stored,
    required IconData placeholder,
    required ThemeData theme,
  }) {
    final file = picked ?? MediaStore.instance.resolveFile(stored);
    if (file == null) {
      return Icon(placeholder, color: theme.colorScheme.onSurfaceVariant);
    }
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (context, _, __) => Icon(
        placeholder,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Moves a freshly picked file into permanent storage, returning the name to
  /// persist. Null when nothing new was picked, so the existing value stands.
  Future<String?> _storeAttachment(File? file, String prefix) async {
    if (file == null) return null;
    return MediaStore.instance.save(file, prefix: prefix);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _pageError = null;
    });

    try {
      final now = DateTime.now();
      final client = ClientModel(
        id: widget.client?.id,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        cin: _cinController.text.trim(),
        licenseNumber: _licenseNumberController.text.trim(),
        // Address removed from UI; keep existing value if editing.
        address: widget.client?.address,
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        // Copied out of the picker's cache first; storing the temporary path
        // is what made attachments disappear between sessions.
        cinImagePath: await _storeAttachment(_cinImageFile, 'cin') ??
            widget.client?.cinImagePath,
        licenseImagePath:
            await _storeAttachment(_licenseImageFile, 'permis') ??
                widget.client?.licenseImagePath,
        createdAt: widget.client?.createdAt ?? now,
        updatedAt: now,
      );

      final notifier = ref.read(clientsProvider.notifier);

      if (widget.client == null) {
        await notifier.addClient(client);
      } else {
        await notifier.updateClient(client);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pageError = _humanizeError(e);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.client != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier un client' : 'Nouveau client'),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        // Pad past the system navigation bar so the last control is
        // not trapped under the phone's back/home buttons.
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_pageError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Impossible d’enregistrer le client',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _pageError!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fermer',
                          onPressed: () => setState(() => _pageError = null),
                          icon: Icon(
                            Icons.close,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                AppTextField(
                                  controller: _firstNameController,
                                  label: 'Prénom',
                                  prefixIcon: Icons.person_outline,
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Le prénom est requis.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  controller: _lastNameController,
                                  label: 'Nom',
                                  prefixIcon: Icons.person,
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Le nom est requis.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  controller: _cinController,
                                  label: 'CIN',
                                  prefixIcon: Icons.badge_outlined,
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Le CIN est requis.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  controller: _licenseNumberController,
                                  label: 'Numéro de permis',
                                  prefixIcon: Icons.credit_card,
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Le numéro de permis est requis.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  controller: _phoneController,
                                  label: 'Téléphone',
                                  keyboardType: TextInputType.phone,
                                  prefixIcon: Icons.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: Validators.phone,
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            children: [
                              Text(
                                'CIN',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 120,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: theme.colorScheme.surfaceContainerHighest,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _attachmentPreview(
                                  picked: _cinImageFile,
                                  stored: widget.client?.cinImagePath,
                                  placeholder: Icons.badge_outlined,
                                  theme: theme,
                                ),
                              ),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                onPressed: _isLoadingOcr ? null : _importCin,
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: const Text('Importer CIN'),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Permis',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 120,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: theme.colorScheme.surfaceContainerHighest,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _attachmentPreview(
                                  picked: _licenseImageFile,
                                  stored: widget.client?.licenseImagePath,
                                  placeholder: Icons.credit_card,
                                  theme: theme,
                                ),
                              ),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                onPressed: _isLoadingOcr ? null : _importPermis,
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: const Text('Importer Permis'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_isLoadingOcr)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: isEditing ? 'Enregistrer' : 'Créer',
                        icon: Icons.save,
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

