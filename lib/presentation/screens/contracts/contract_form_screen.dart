import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/document/document_text_service.dart';
import '../../../core/ocr/ocr_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/notifications/notification_service.dart';
import '../../widgets/common/camera_capture_dialog.dart';
import '../../../data/models/contract_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/models/client_model.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../../data/repositories/client_repository.dart';
import '../../providers/contract_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/client_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/empty_state_widget.dart';

class ContractFormScreen extends ConsumerStatefulWidget {
  const ContractFormScreen({super.key});

  @override
  ConsumerState<ContractFormScreen> createState() =>
      _ContractFormScreenState();
}

class _ContractFormScreenState extends ConsumerState<ContractFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

  VehicleModel? _selectedVehicle;
  ClientModel? _primaryDriver;
  ClientModel? _secondaryDriver;

  DateTime _startDate = DateTime.now();
  DateTime _expectedReturnDate = DateTime.now().add(const Duration(days: 1));
  int _durationDays = 1;

  double _amountPaid = 0;
  double _totalPrice = 0;
  double _dailyPrice = 0;
  
  final _dailyPriceController = TextEditingController();
  final _totalPriceController = TextEditingController();
  final _amountPaidController = TextEditingController();

  bool _isSubmitting = false;
  bool _isImportingOcr = false;


  bool _isNewPrimaryDriver = false;
  bool _isNewSecondaryDriver = false;
  bool _hasSecondaryDriver = false;

  DateTime? _newPrimaryLicenseExpiry;
  DateTime? _newSecondaryLicenseExpiry;

  final _newPrimaryFirstName = TextEditingController();
  final _newPrimaryLastName = TextEditingController();
  final _newPrimaryCin = TextEditingController();
  final _newPrimaryLicense = TextEditingController();
  final _newPrimaryPhone = TextEditingController();

  final _newSecondaryFirstName = TextEditingController();
  final _newSecondaryLastName = TextEditingController();
  final _newSecondaryCin = TextEditingController();
  final _newSecondaryLicense = TextEditingController();
  final _newSecondaryPhone = TextEditingController();

  // Recherche dans la liste des clients (conducteur principal / secondaire).
  String _clientSearchQuery = '';
  String _secondaryClientSearchQuery = '';

  final OcrService _ocrService = OcrService();
  final DocumentTextService _documentService = DocumentTextService.instance;
  static const _tmpPrefix = 'carrent_import_';
  static const List<int> _allowedDurations = [1, 2, 3, 4, 5, 6, 7, 10, 15, 30];

  static const List<String> _imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'bmp',
    'gif',
    'webp',
  ];

  int _normalizeDurationDays(int days) {
    if (days <= 0) return 1;
    if (_allowedDurations.contains(days)) return days;
    var closest = _allowedDurations.first;
    var bestDiff = (closest - days).abs();
    for (final d in _allowedDurations) {
      final diff = (d - days).abs();
      if (diff < bestDiff) {
        closest = d;
        bestDiff = diff;
      }
    }
    return closest;
  }


  @override
  void dispose() {
    _newPrimaryFirstName.dispose();
    _newPrimaryLastName.dispose();
    _newPrimaryCin.dispose();
    _newPrimaryLicense.dispose();
    _newPrimaryPhone.dispose();
    _newSecondaryFirstName.dispose();
    _newSecondaryLastName.dispose();
    _newSecondaryCin.dispose();
    _newSecondaryLicense.dispose();
    _newSecondaryPhone.dispose();
    _dailyPriceController.dispose();
    _totalPriceController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(vehiclesProvider.notifier).loadVehicles();
      await ref.read(clientsProvider.notifier).loadClients();
      if (mounted) {
        final clients = ref.read(clientsProvider).value ?? [];
        if (clients.isEmpty) {
          setState(() {
            _isNewPrimaryDriver = true;
          });
        }
      }
    });
  }

  int get _rentalDays {
    final diff = _expectedReturnDate.difference(_startDate).inDays;
    return diff <= 0 ? 1 : diff;
  }

  double get _remaining => _totalPrice - _amountPaid;

  void _updateTotalPrice() {
    _totalPrice = _dailyPrice * _durationDays;
    _totalPriceController.text = _totalPrice == 0 ? '' : _totalPrice.toStringAsFixed(2);
  }

  List<ClientModel> _filteredClients(
    List<ClientModel> clients,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return clients;
    return clients
        .where(
          (c) =>
              c.fullName.toLowerCase().contains(q) ||
              (c.cin ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  void _syncSelectedDriversWithFilter(List<ClientModel> clients) {
    final filtered = _filteredClients(clients, _clientSearchQuery);
    if (_primaryDriver != null &&
        !filtered.any((c) => c.id == _primaryDriver!.id)) {
      _primaryDriver = null;
    }
    if (_secondaryDriver != null &&
        !filtered.any((c) => c.id == _secondaryDriver!.id)) {
      _secondaryDriver = null;
    }
  }

  Future<File?> _pickDriverImage() async {
    // Show source picker: camera or files
    final useCamera = await showModalBottomSheet<bool?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Prendre une photo'),
                subtitle: const Text('Utiliser la cam\u00e9ra'),
                onTap: () => Navigator.pop(ctx, true),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Choisir un fichier'),
                subtitle: const Text('Image depuis l\'appareil'),
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (useCamera == null) return null;

    if (useCamera == true) {
      if (Platform.isMacOS || Platform.isWindows) {
        final result = await showDialog<File?>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const CameraCaptureDialog(),
        );
        return result;
      }

      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 95,
        );
        if (picked == null) return null;
        return File(picked.path);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caméra non disponible. Sélection depuis les fichiers.')),
          );
        }
      }
    }

    // File picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _imageExtensions,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final pickedFile = result.files.single;
    final bytes = pickedFile.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      final ext = (pickedFile.extension ?? '').isNotEmpty
          ? pickedFile.extension!
          : (pickedFile.name.contains('.') ? pickedFile.name.split('.').last : 'jpg');
      final tmp = File(
        '${Directory.systemTemp.path}/${_tmpPrefix}${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await tmp.writeAsBytes(bytes, flush: true);
      return tmp;
    }
    final path = pickedFile.path;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file;
  }







  Future<void> _importDriverOcr({
    required bool isPrimary,
    required bool isPermis,
    required List<ClientModel> clients,
  }) async {
    if (_isImportingOcr) return;
    final file = await _pickDriverImage();
    if (file == null) return;
    setState(() => _isImportingOcr = true);
    try {
      final text = await _ocrService.extractText(file.path);
      if (text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun texte extrait.')));
        }
        return;
      }
      final data = isPermis ? _ocrService.parseLicenseData(text) : _ocrService.parseCINData(text);
      final isNew = isPrimary ? _isNewPrimaryDriver : _isNewSecondaryDriver;
      if (isNew) {
        setState(() {
          final fn = data['firstName'] ?? '';
          final ln = data['lastName'] ?? '';
          // The permis prints the holder's CIN under N.C.N.I.E., so it is
          // usable from either document.
          final cn = data['cin'] ?? '';
          final lic = isPermis ? (data['licenseNumber'] ?? '') : '';
          final expiry = data['expiryDate'] ?? '';
          
          if (isPrimary) {
            if (fn.isNotEmpty && _newPrimaryFirstName.text.isEmpty) _newPrimaryFirstName.text = fn;
            if (ln.isNotEmpty && _newPrimaryLastName.text.isEmpty) _newPrimaryLastName.text = ln;
            if (cn.isNotEmpty && _newPrimaryCin.text.isEmpty) _newPrimaryCin.text = cn;
            if (lic.isNotEmpty && _newPrimaryLicense.text.isEmpty) _newPrimaryLicense.text = lic;
            if (expiry.isNotEmpty) _newPrimaryLicenseExpiry = _parseDate(expiry);
          } else {
            if (fn.isNotEmpty && _newSecondaryFirstName.text.isEmpty) _newSecondaryFirstName.text = fn;
            if (ln.isNotEmpty && _newSecondaryLastName.text.isEmpty) _newSecondaryLastName.text = ln;
            if (cn.isNotEmpty && _newSecondaryCin.text.isEmpty) _newSecondaryCin.text = cn;
            if (lic.isNotEmpty && _newSecondaryLicense.text.isEmpty) _newSecondaryLicense.text = lic;
            if (expiry.isNotEmpty) _newSecondaryLicenseExpiry = _parseDate(expiry);
          }
        });
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Champs remplis selon le document.')));
        }
      } else {
        final cin = (data['cin'] ?? '').trim();
        if (cin.isEmpty && !isPermis) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CIN non reconnu.')));
          return;
        }
        ClientModel? matched;
        try {
          matched = clients.firstWhere((c) => (c.cin ?? '').toUpperCase() == cin.toUpperCase());
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          if (matched != null) {
            if (isPrimary) {
              _primaryDriver = matched;
              if (_secondaryDriver?.id == matched.id) _secondaryDriver = null;
            } else {
              if (_primaryDriver?.id != matched.id) _secondaryDriver = matched;
            }
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(matched != null ? 'Conducteur sélectionné.' : 'Client non trouvé dans la base.')),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur import: $e')));
    } finally {
      if (mounted) setState(() => _isImportingOcr = false);
    }
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDate),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!_expectedReturnDate.isAfter(_startDate)) {
        _expectedReturnDate = _startDate.add(const Duration(days: 1));
      }
      _durationDays = _normalizeDurationDays(_startDate.difference(_expectedReturnDate).inDays.abs());
      _updateTotalPrice();
    });
  }

  Future<void> _importDocument(List<ClientModel> clients) async {
    if (_isImportingOcr) return;
    final pickedResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _documentService.allowedExtensions,
      allowMultiple: false,
      withData: true,
    );
    if (pickedResult == null || pickedResult.files.isEmpty) return;
    final picked = pickedResult.files.single;

    File? file;
    String ext = '';
    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      ext = (picked.extension ?? '').isNotEmpty
          ? picked.extension!.toLowerCase()
          : (picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : '');
      final tmp = File(
        '${Directory.systemTemp.path}/$_tmpPrefix${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'bin' : ext}',
      );
      await tmp.writeAsBytes(picked.bytes!, flush: true);
      file = tmp;
    } else if (picked.path != null) {
      file = File(picked.path!);
      if (!await file.exists()) return;
      ext = picked.path!.split('.').last.toLowerCase();
    }
    if (file == null) return;

    setState(() => _isImportingOcr = true);
    try {
      String text;
      try {
        text = await _ocrService.extractText(file.path);
      } catch (_) {
        text = '';
      }
      if (!mounted) return;
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun texte extrait. Essayez un autre fichier.')),
        );
        return;
      }
      final data = _ocrService.parseContractDocument(text);
      final cin = (data['cin'] ?? '').trim();
      final amountStr = (data['amount'] ?? '').trim();
      final startStr = (data['startDate'] ?? '').trim();
      final endStr = (data['endDate'] ?? '').trim();
      ClientModel? matched;
      if (cin.isNotEmpty) {
        try {
          matched = clients.firstWhere((c) => c.cin == cin);
        } catch (_) {
          matched = null;
        }
      }
      setState(() {
        if (matched != null) _primaryDriver = matched;
        if (amountStr.isNotEmpty) {
          final a = double.tryParse(amountStr);
          if (a != null && a >= 0) {
            _amountPaid = a;
            _amountPaidController.text = _amountPaid.toStringAsFixed(2);
          }
        }
        final start = _parseDate(startStr);
        if (start != null) _startDate = start;
        final end = _parseDate(endStr);
        if (end != null && end.isAfter(_startDate)) _expectedReturnDate = end;
        _durationDays = _normalizeDurationDays(_rentalDays);
        _updateTotalPrice();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              matched != null
                  ? 'Client et données remplis à partir du document.'
                  : 'Données extraites. Vérifiez et sélectionnez le client si besoin.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur import: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingOcr = false);
    }
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    final dash = s.split(RegExp(r'[/\-]'));
    if (dash.length != 3) return null;
    int? day, month, year;
    if (dash[0].length == 4) {
      year = int.tryParse(dash[0]);
      month = int.tryParse(dash[1]);
      day = int.tryParse(dash[2]);
    } else {
      day = int.tryParse(dash[0]);
      month = int.tryParse(dash[1]);
      year = int.tryParse(dash[2]);
    }
    if (year == null || month == null || day == null) return null;
    int y = year;
    if (y < 100) y = 2000 + y;
    try {
      return DateTime(y, month, day);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickExpectedReturnDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedReturnDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expectedReturnDate),
    );
    if (time == null || !mounted) return;
    setState(() {
      _expectedReturnDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      // Keep duration in sync when the end date is adjusted manually.
      final diff = _expectedReturnDate.difference(_startDate).inDays;
      _durationDays = _normalizeDurationDays(diff);
      _updateTotalPrice();
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez un véhicule.')));
      return;
    }

    if (_isNewPrimaryDriver) {
      if (_newPrimaryFirstName.text.trim().isEmpty || 
          _newPrimaryLastName.text.trim().isEmpty || 
          _newPrimaryCin.text.trim().isEmpty ||
          _newPrimaryLicense.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom, Prénom, CIN et Permis sont requis pour le conducteur principal.')));
        return;
      }
    } else {
      if (_primaryDriver == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez un conducteur principal.')));
        return;
      }
    }

    if (_hasSecondaryDriver && _isNewSecondaryDriver) {
      if (_newSecondaryFirstName.text.trim().isEmpty || 
          _newSecondaryLastName.text.trim().isEmpty ||
          _newSecondaryCin.text.trim().isEmpty ||
          _newSecondaryLicense.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom, Prénom, CIN et Permis sont requis pour le conducteur secondaire.')));
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    // --- SMART VALIDATION ---
    final warnings = <String>[];
    
    // 1. Same driver check
    final pCin = _isNewPrimaryDriver ? _newPrimaryCin.text.trim() : _primaryDriver?.cin;
    final sCin = _hasSecondaryDriver ? (_isNewSecondaryDriver ? _newSecondaryCin.text.trim() : _secondaryDriver?.cin) : null;
    if (_hasSecondaryDriver && pCin == sCin && pCin != null && pCin.isNotEmpty) {
      warnings.add('Le conducteur principal et secondaire sont identiques.');
    }

    // 2. License expiry check
    final pExpiry = _isNewPrimaryDriver ? _newPrimaryLicenseExpiry : _primaryDriver?.licenseExpiryDate;
    if (pExpiry != null && pExpiry.isBefore(DateTime.now())) {
      warnings.add('Le permis du conducteur principal est expiré (${DateFormat('dd/MM/yyyy').format(pExpiry)}).');
    }
    
    final sExpiry = _hasSecondaryDriver ? (_isNewSecondaryDriver ? _newSecondaryLicenseExpiry : _secondaryDriver?.licenseExpiryDate) : null;
    if (sExpiry != null && sExpiry.isBefore(DateTime.now())) {
      warnings.add('Le permis du conducteur secondaire est expiré (${DateFormat('dd/MM/yyyy').format(sExpiry)}).');
    }

    if (warnings.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Avertissements'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: warnings.map<Widget>((w) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text('• $w'),
            )).toList()..add(const Text('\nSouhaitez-vous quand même continuer ?')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ANNULER'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CONTINUER'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        setState(() => _isSubmitting = false);
        return;
      }
    }
    // --- END SMART VALIDATION ---


    try {
      final repo = ContractRepository.instance;
      final contractNumber = await repo.generateContractNumber();
      final rawNow = DateTime.now();
      DateTime adjustedNow = rawNow;
      if (rawNow.hour >= 18) {
        adjustedNow = DateTime(rawNow.year, rawNow.month, rawNow.day, 18, 0);
      } else if (rawNow.hour < 8) {
        final prev = rawNow.subtract(const Duration(days: 1));
        adjustedNow = DateTime(prev.year, prev.month, prev.day, 18, 0);
      }
      final now = adjustedNow;

      final clientRepo = ClientRepository.instance;
      int primaryId;
      if (_isNewPrimaryDriver) {
          final pCin = _newPrimaryCin.text.trim();
          final pLic = _newPrimaryLicense.text.trim();
          final pPhone = _newPrimaryPhone.text.trim();
          primaryId = await clientRepo.insertClient(ClientModel(
              firstName: _newPrimaryFirstName.text.trim(),
              lastName: _newPrimaryLastName.text.trim(),
              cin: pCin.isEmpty ? 'NON_RENSEIGNE_${now.millisecondsSinceEpoch}' : pCin,
              licenseNumber: pLic,
              licenseExpiryDate: _newPrimaryLicenseExpiry,
              phone: pPhone.isEmpty ? '0000000000' : pPhone,
              createdAt: now,
              updatedAt: now,
          ));
      } else {
          primaryId = _primaryDriver!.id!;
      }

      int? secondaryId;
      if (_hasSecondaryDriver) {
          if (_isNewSecondaryDriver) {
              final sCin = _newSecondaryCin.text.trim();
              final sLic = _newSecondaryLicense.text.trim();
              final sPhone = _newSecondaryPhone.text.trim();
              secondaryId = await clientRepo.insertClient(ClientModel(
                  firstName: _newSecondaryFirstName.text.trim(),
                  lastName: _newSecondaryLastName.text.trim(),
                  cin: sCin,
                  licenseNumber: sLic,
                  licenseExpiryDate: _newSecondaryLicenseExpiry,
                  phone: sPhone.isEmpty ? '0000000000' : sPhone,
                  createdAt: now,
                  updatedAt: now,
              ));
          } else {
              secondaryId = _secondaryDriver?.id;
          }
      }

      await ref.read(clientsProvider.notifier).loadClients();

      final contract = ContractModel(
        id: null,
        contractNumber: contractNumber,
        vehicleId: _selectedVehicle!.id!,
        primaryDriverId: primaryId,
        secondaryDriverId: secondaryId,
        startDate: _startDate,
        expectedReturnDate: _expectedReturnDate,
        actualReturnDate: null,
        totalPrice: _totalPrice,
        amountPaid: _amountPaid,
        status: 'active',
        notes: null,
        createdAt: now,
        updatedAt: now,
      );

      final newId = await repo.insertContract(contract);
      await ref.read(contractsProvider.notifier).loadContracts();
      await ref.read(dashboardProvider.notifier).refresh();

      await NotificationService.instance.scheduleReturnReminder(
        contractId: newId,
        registrationNumber: _selectedVehicle!.registrationNumber,
        returnDate: _expectedReturnDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
      context.go('/contracts');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la création du contrat.\n'
            'حدث خطأ أثناء إنشاء العقد.\n'
            'Contract creation error: $e',
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
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final clientsAsync = ref.watch(clientsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau contrat'),
      ),
      body: vehiclesAsync.when(
        data: (vehicles) {
          final availableVehicles =
              vehicles.where((v) => v.status == 'available').toList();

          if (availableVehicles.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyStateWidget(
                title: 'Aucun véhicule disponible.',
                subtitle:
                    'Ajoutez un véhicule ou libérez un contrat existant.',
                icon: Icons.directions_car_filled_outlined,
              ),
            );
          }

          return clientsAsync.when(
            data: (clients) {
              return SingleChildScrollView(
                // Pad past the system navigation bar, otherwise the submit
                // button at the end of the form sits under the phone's
                // back/home buttons and cannot be tapped.
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            '1. Véhicule',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<VehicleModel>(
                            value: _selectedVehicle,
                            items: availableVehicles
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      '${v.brand} ${v.model} (${v.registrationNumber})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedVehicle = v;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Véhicule',
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          Text(
                            '2. Conducteur principal',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          // Radios and scan buttons share a line on desktop and
                          // fall onto separate lines on a phone, where a single
                          // Row overflowed.
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              // Both options together exceed a phone's width,
                              // so they wrap onto separate lines when needed.
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<bool>(
                                        value: false,
                                        groupValue: _isNewPrimaryDriver,
                                        onChanged: (v) => setState(() => _isNewPrimaryDriver = v!),
                                      ),
                                      const Text('Client existant'),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<bool>(
                                        value: true,
                                        groupValue: _isNewPrimaryDriver,
                                        onChanged: (v) => setState(() => _isNewPrimaryDriver = v!),
                                      ),
                                      const Text('Nouveau client'),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isNewPrimaryDriver) ...[
                                    OutlinedButton.icon(
                                      onPressed: _isImportingOcr ? null : () => _importDriverOcr(isPrimary: true, isPermis: false, clients: clients),
                                      icon: const Icon(Icons.badge_outlined, size: 18),
                                      label: const Text('CIN'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: _isImportingOcr ? null : () => _importDriverOcr(isPrimary: true, isPermis: true, clients: clients),
                                      icon: const Icon(Icons.credit_card, size: 18),
                                      label: const Text('Permis'),
                                    ),
                                  ] else ...[
                                    OutlinedButton.icon(
                                      onPressed: _isImportingOcr ? null : () => _importDriverOcr(isPrimary: true, isPermis: false, clients: clients),
                                      icon: const Icon(Icons.credit_card, size: 18),
                                      label: const Text('Importer CIN'),
                                    ),
                                  ]
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isNewPrimaryDriver) ...[
                             Row(children: [
                               Expanded(child: TextFormField(controller: _newPrimaryFirstName, decoration: const InputDecoration(labelText: 'Prénom'))),
                               const SizedBox(width: 8),
                               Expanded(child: TextFormField(controller: _newPrimaryLastName, decoration: const InputDecoration(labelText: 'Nom'))),
                             ]),
                             const SizedBox(height: 8),
                             Row(children: [
                               Expanded(child: TextFormField(controller: _newPrimaryCin, decoration: const InputDecoration(labelText: 'CIN'))),
                               const SizedBox(width: 8),
                               Expanded(child: TextFormField(controller: _newPrimaryLicense, decoration: const InputDecoration(labelText: 'Numéro Permis'))),
                             ]),
                             const SizedBox(height: 8),
                             TextFormField(controller: _newPrimaryPhone, decoration: const InputDecoration(labelText: 'Téléphone (optionnel)')),
                          ] else ...[
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Rechercher un conducteur',
                                hintText: 'Nom ou CIN',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _clientSearchQuery = value;
                                  _syncSelectedDriversWithFilter(clients);
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<ClientModel>(
                              value: _primaryDriver != null &&
                                      _filteredClients(clients, _clientSearchQuery).any((c) => c.id == _primaryDriver!.id)
                                  ? _primaryDriver
                                  : null,
                              items: _filteredClients(clients, _clientSearchQuery)
                                  .map((c) => DropdownMenuItem(value: c, child: Text('${c.fullName} (${c.cin})')))
                                  .toList(),
                              onChanged: (c) {
                                setState(() {
                                  _primaryDriver = c;
                                  if (c != null && _secondaryDriver?.id == c.id) {
                                    _secondaryDriver = null;
                                  }
                                });
                              },
                              decoration: const InputDecoration(labelText: 'Conducteur principal'),
                            ),
                          ],
                          const SizedBox(height: 16),

                          
                          Row(
                            children: [
                              Checkbox(value: _hasSecondaryDriver, onChanged: (v) => setState(() => _hasSecondaryDriver = v!)),
                              Text(
                                '3. Conducteur secondaire (optionnel)',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ]
                          ),
                          if (_hasSecondaryDriver) ...[
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<bool>(
                                          value: false,
                                          groupValue: _isNewSecondaryDriver,
                                          onChanged: (v) => setState(() => _isNewSecondaryDriver = v!),
                                        ),
                                        const Text('Client existant'),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<bool>(
                                          value: true,
                                          groupValue: _isNewSecondaryDriver,
                                          onChanged: (v) => setState(() => _isNewSecondaryDriver = v!),
                                        ),
                                        const Text('Nouveau client'),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isNewSecondaryDriver) ...[
                                      OutlinedButton.icon(
                                        onPressed: _isImportingOcr ? null : () => _importDriverOcr(isPrimary: false, isPermis: false, clients: clients),
                                        icon: const Icon(Icons.badge_outlined, size: 18),
                                        label: const Text('CIN'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: _isImportingOcr ? null : () => _importDriverOcr(isPrimary: false, isPermis: true, clients: clients),
                                        icon: const Icon(Icons.credit_card, size: 18),
                                        label: const Text('Permis'),
                                      ),
                                    ] else ...[
                                      OutlinedButton.icon(
                                        onPressed: _isImportingOcr ? null : () => _importDriverOcr(isPrimary: false, isPermis: false, clients: clients),
                                        icon: const Icon(Icons.credit_card, size: 18),
                                        label: const Text('Importer CIN'),
                                      ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_isNewSecondaryDriver) ...[
                              Row(children: [
                                 Expanded(child: TextFormField(controller: _newSecondaryFirstName, decoration: const InputDecoration(labelText: 'Prénom'))),
                                 const SizedBox(width: 8),
                                 Expanded(child: TextFormField(controller: _newSecondaryLastName, decoration: const InputDecoration(labelText: 'Nom'))),
                               ]),
                               const SizedBox(height: 8),
                               Row(children: [
                                 Expanded(child: TextFormField(controller: _newSecondaryCin, decoration: const InputDecoration(labelText: 'CIN'))),
                                 const SizedBox(width: 8),
                                 Expanded(child: TextFormField(controller: _newSecondaryLicense, decoration: const InputDecoration(labelText: 'Numéro Permis'))),
                               ]),
                               const SizedBox(height: 8),
                               TextFormField(controller: _newSecondaryPhone, decoration: const InputDecoration(labelText: 'Téléphone (optionnel)')),
                            ] else ...[
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Rechercher un conducteur secondaire',
                                  hintText: 'Nom ou CIN',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _secondaryClientSearchQuery = value;
                                    final filtered = _filteredClients(clients, _secondaryClientSearchQuery);
                                    if (_secondaryDriver != null && !filtered.any((c) => c.id == _secondaryDriver!.id)) {
                                      _secondaryDriver = null;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<ClientModel?>(
                                value: (() {
                                  final current = _secondaryDriver;
                                  if (current == null) return null;
                                  if (_primaryDriver != null && current.id == _primaryDriver!.id) return null;
                                  final filtered = _filteredClients(clients, _secondaryClientSearchQuery).where(
                                    (c) => _primaryDriver == null || c.id != _primaryDriver!.id,
                                  );
                                  return filtered.any((c) => c.id == current.id) ? current : null;
                                })(),
                                items: [
                                  const DropdownMenuItem<ClientModel?>(value: null, child: Text('Aucun')),
                                  ..._filteredClients(clients, _secondaryClientSearchQuery)
                                      .where((c) => _primaryDriver == null || c.id != _primaryDriver!.id)
                                      .map((c) => DropdownMenuItem<ClientModel?>(value: c, child: Text('${c.fullName} (${c.cin})'))),
                                ],
                                onChanged: (ClientModel? c) {
                                  setState(() {
                                    _secondaryDriver = c;
                                  });
                                },
                                decoration: const InputDecoration(labelText: 'Conducteur secondaire'),
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),

                          Text(
                            '4. Période de location',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Date de début'),
                                  subtitle: Text(
                                    _dateFormatter.format(_startDate),
                                  ),
                                  trailing:
                                      const Icon(Icons.date_range_outlined),
                                  onTap: _pickStartDate,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Retour prévu'),
                                  subtitle: Text(
                                    _dateFormatter.format(_expectedReturnDate),
                                  ),
                                  trailing:
                                      const Icon(Icons.date_range_outlined),
                                  onTap: _pickExpectedReturnDate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Durée:'),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: _allowedDurations.contains(_durationDays)
                                    ? _durationDays
                                    : _allowedDurations.first,
                                items: _allowedDurations
                                    .map(
                                      (d) => DropdownMenuItem<int>(
                                        value: d,
                                        child: Text('$d jours'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _durationDays = _normalizeDurationDays(value);
                                    _expectedReturnDate =
                                        _startDate.add(Duration(days: _durationDays));
                                    _updateTotalPrice();
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '5. Paiement',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _dailyPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Prix journalier (MAD)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              setState(() {
                                _dailyPrice = double.tryParse(value) ?? 0;
                                _updateTotalPrice();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _totalPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Prix total du contrat (MAD)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              setState(() {
                                _totalPrice = double.tryParse(value) ?? 0;
                                // Automatically update daily price if total price is set manually
                                if (_durationDays > 0 && value.isNotEmpty) {
                                  _dailyPrice = _totalPrice / _durationDays;
                                  _dailyPriceController.text = _dailyPrice.toStringAsFixed(2);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _amountPaidController,
                            decoration: const InputDecoration(
                              labelText: 'Montant payé (MAD)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              setState(() {
                                _amountPaid = double.tryParse(value) ?? 0;
                              });
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reste à payer: ${_remaining.toStringAsFixed(2)} MAD',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            label: 'Créer le contrat',
                            icon: Icons.check_circle_outline,
                            isLoading: _isSubmitting,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Erreur lors du chargement des clients.\n'
                'خطأ أثناء تحميل الزبناء.\n'
                'Clients loading error: $error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Erreur lors du chargement des véhicules.\n'
            'خطأ أثناء تحميل السيارات.\n'
            'Vehicles loading error: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

