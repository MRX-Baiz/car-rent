import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/models/client_model.dart';
import '../../providers/client_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

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

enum ClientFormMode { manual, ocr }

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _cinController;
  late final TextEditingController _licenseNumberController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  File? _cinImageFile;
  File? _licenseImageFile;

  ClientFormMode _mode = ClientFormMode.manual;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _firstNameController = TextEditingController(text: c?.firstName ?? '');
    _lastNameController = TextEditingController(text: c?.lastName ?? '');
    _cinController = TextEditingController(text: c?.cin ?? '');
    _licenseNumberController =
        TextEditingController(text: c?.licenseNumber ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cinController.dispose();
    _licenseNumberController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickCinImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
    );
    if (picked != null) {
      setState(() {
        _cinImageFile = File(picked.path);
      });
      // Placeholder for OCR integration: the OCR service can be called here
      // to extract CIN information and pre-fill fields.
    }
  }

  Future<void> _pickLicenseImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
    );
    if (picked != null) {
      setState(() {
        _licenseImageFile = File(picked.path);
      });
      // Placeholder for OCR integration for license data.
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final now = DateTime.now();
      final client = ClientModel(
        id: widget.client?.id,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        cin: _cinController.text.trim(),
        licenseNumber: _licenseNumberController.text.trim(),
        address:
            _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        cinImagePath: _cinImageFile?.path ?? widget.client?.cinImagePath,
        licenseImagePath:
            _licenseImageFile?.path ?? widget.client?.licenseImagePath,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l’enregistrement du client.\n'
            'حدث خطأ أثناء حفظ الزبون.\n'
            'Client save error: $e',
          ),
        ),
      );
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
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ToggleButtons(
                  isSelected: [
                    _mode == ClientFormMode.manual,
                    _mode == ClientFormMode.ocr,
                  ],
                  onPressed: (index) {
                    setState(() {
                      _mode = index == 0
                          ? ClientFormMode.manual
                          : ClientFormMode.ocr;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  children: const [
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Saisie manuelle'),
                    ),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Mode scan'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                                  controller: _addressController,
                                  label: 'Adresse',
                                  prefixIcon: Icons.home_outlined,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  controller: _phoneController,
                                  label: 'Téléphone',
                                  keyboardType: TextInputType.phone,
                                  prefixIcon: Icons.phone,
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Le téléphone est requis.';
                                    }
                                    return null;
                                  },
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
                                  color: theme.colorScheme.surfaceVariant,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _cinImageFile != null
                                    ? Image.file(
                                        _cinImageFile!,
                                        fit: BoxFit.cover,
                                      )
                                    : (widget.client?.cinImagePath != null
                                        ? Image.file(
                                            File(widget.client!.cinImagePath!),
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            Icons.badge_outlined,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          )),
                              ),
                              const SizedBox(height: 4),
                              TextButton.icon(
                                onPressed: _mode == ClientFormMode.ocr
                                    ? _pickCinImage
                                    : null,
                                icon: const Icon(Icons.document_scanner),
                                label: const Text('Scanner'),
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
                                  color: theme.colorScheme.surfaceVariant,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _licenseImageFile != null
                                    ? Image.file(
                                        _licenseImageFile!,
                                        fit: BoxFit.cover,
                                      )
                                    : (widget.client?.licenseImagePath != null
                                        ? Image.file(
                                            File(widget
                                                .client!.licenseImagePath!),
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            Icons.credit_card,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          )),
                              ),
                              const SizedBox(height: 4),
                              TextButton.icon(
                                onPressed: _mode == ClientFormMode.ocr
                                    ? _pickLicenseImage
                                    : null,
                                icon: const Icon(Icons.document_scanner),
                                label: const Text('Scanner'),
                              ),
                            ],
                          ),
                        ],
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

