import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/document/document_text_service.dart';
import '../../../core/ocr/ocr_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../widgets/common/camera_capture_dialog.dart';
import '../../../data/models/contract_model.dart';
import '../../../domain/entities/reservation.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/models/client_model.dart';
import '../../providers/contract_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/chauffeur_provider.dart';
import '../../../data/models/chauffeur_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/vehicle_labels.dart';
import '../../widgets/common/alert_banner.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/form_section.dart';
import '../../widgets/common/plate_badge.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/common/vehicle_photo.dart';

class ContractFormScreen extends ConsumerStatefulWidget {
  const ContractFormScreen({
    super.key,
    this.initialVehicleId,
    this.reservation,
  });

  /// Set when the form is opened from a vehicle's page.
  final int? initialVehicleId;

  /// A confirmed quote carries its vehicle, dates, price and optional client
  /// straight into the contract form. The quote is marked converted only when
  /// this form successfully saves the contract.
  final Reservation? reservation;

  @override
  ConsumerState<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends ConsumerState<ContractFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

  VehicleModel? _selectedVehicle;
  ClientModel? _primaryDriver;
  ClientModel? _secondaryDriver;
  ChauffeurModel? _chauffeur;
  final _chauffeurHoursController = TextEditingController();

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
    _chauffeurHoursController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final reservation = widget.reservation;
    if (reservation != null) {
      _startDate = reservation.startDate;
      _expectedReturnDate = reservation.expectedReturnDate;
      _durationDays = reservation.rentalDays;
      _dailyPrice = reservation.dailyPrice;
      _totalPrice = reservation.totalPrice;
      _dailyPriceController.text = reservation.dailyPrice.toStringAsFixed(2);
      _totalPriceController.text = reservation.totalPrice.toStringAsFixed(2);
    }
    Future.microtask(() async {
      await ref.read(vehiclesProvider.notifier).loadVehicles();
      await ref.read(clientsProvider.notifier).loadClients();
      await ref.read(chauffeursProvider.notifier).load();
      if (mounted) {
        final preselected =
            widget.reservation?.vehicleId ?? widget.initialVehicleId;
        if (preselected != null) {
          final vehicles = ref.read(vehiclesProvider).value ?? [];
          final match = vehicles
              .where((v) =>
                  v.id == preselected &&
                  (widget.reservation != null || v.status == 'available'))
              .firstOrNull;
          if (match != null) setState(() => _selectedVehicle = match);
        }
        final clients = ref.read(clientsProvider).value ?? [];
        final reservedClient = _clientWithId(clients, reservation?.clientId);
        if (reservedClient != null) {
          setState(() => _primaryDriver = reservedClient);
        }
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
    _totalPrice = _dailyPrice * _durationDays +
        ((_chauffeur?.hourlyRate ?? 0) *
            (double.tryParse(_chauffeurHoursController.text) ?? 0));
    _totalPriceController.text =
        _totalPrice == 0 ? '' : _totalPrice.toStringAsFixed(2);
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

  List<ClientModel> _uniqueClients(List<ClientModel> clients, String query) {
    final unique = <int, ClientModel>{};
    for (final client in _filteredClients(clients, query)) {
      if (client.id != null) unique.putIfAbsent(client.id!, () => client);
    }
    return unique.values.toList();
  }

  ClientModel? _clientWithId(List<ClientModel> clients, int? id) {
    if (id == null) return null;
    for (final client in clients) {
      if (client.id == id) return client;
    }
    return null;
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
                title: const AppText(AppCopy.takeAPhoto),
                subtitle: const AppText(AppCopy.useCamera),
                onTap: () => Navigator.pop(ctx, true),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const AppText(AppCopy.chooseAFile),
                subtitle: const AppText(AppCopy.imageFromDevice),
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
            const SnackBar(
                content: AppText(AppCopy.cameraUnavailableChooseAFileInstead)),
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
          : (pickedFile.name.contains('.')
              ? pickedFile.name.split('.').last
              : 'jpg');
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
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: AppText(AppCopy.noTextExtracted)));
        }
        return;
      }
      final data = isPermis
          ? _ocrService.parseLicenseData(text)
          : _ocrService.parseCINData(text);
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
            if (fn.isNotEmpty && _newPrimaryFirstName.text.isEmpty)
              _newPrimaryFirstName.text = fn;
            if (ln.isNotEmpty && _newPrimaryLastName.text.isEmpty)
              _newPrimaryLastName.text = ln;
            if (cn.isNotEmpty && _newPrimaryCin.text.isEmpty)
              _newPrimaryCin.text = cn;
            if (lic.isNotEmpty && _newPrimaryLicense.text.isEmpty)
              _newPrimaryLicense.text = lic;
            if (expiry.isNotEmpty)
              _newPrimaryLicenseExpiry = _parseDate(expiry);
          } else {
            if (fn.isNotEmpty && _newSecondaryFirstName.text.isEmpty)
              _newSecondaryFirstName.text = fn;
            if (ln.isNotEmpty && _newSecondaryLastName.text.isEmpty)
              _newSecondaryLastName.text = ln;
            if (cn.isNotEmpty && _newSecondaryCin.text.isEmpty)
              _newSecondaryCin.text = cn;
            if (lic.isNotEmpty && _newSecondaryLicense.text.isEmpty)
              _newSecondaryLicense.text = lic;
            if (expiry.isNotEmpty)
              _newSecondaryLicenseExpiry = _parseDate(expiry);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: AppText(AppCopy.fieldsFilledFromTheDocument)));
        }
      } else {
        final cin = (data['cin'] ?? '').trim();
        if (cin.isEmpty && !isPermis) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: AppText(AppCopy.nationalIDNotRecognised)));
          return;
        }
        ClientModel? matched;
        try {
          matched = clients.firstWhere(
              (c) => (c.cin ?? '').toUpperCase() == cin.toUpperCase());
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
            SnackBar(
                content: AppText(matched != null
                    ? AppCopy.driverSelected
                    : AppCopy.clientNotFoundInTheDatabase)),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(context.trError(e))));
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
      _durationDays = _normalizeDurationDays(
          _startDate.difference(_expectedReturnDate).inDays.abs());
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
          : (picked.name.contains('.')
              ? picked.name.split('.').last.toLowerCase()
              : '');
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
          const SnackBar(
              content: AppText(AppCopy.noTextExtractedTryAnotherFile)),
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
            content: AppText(
              matched != null
                  ? AppCopy.clientAndDetailsFilledFromTheDocument
                  : AppCopy.dataExtractedVerifyItAndSelectTheClient,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(context.trError(e))),
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText(AppCopy.selectAVehicle)));
      return;
    }

    if (_isNewPrimaryDriver) {
      if (_newPrimaryFirstName.text.trim().isEmpty ||
          _newPrimaryLastName.text.trim().isEmpty ||
          _newPrimaryCin.text.trim().isEmpty ||
          _newPrimaryLicense.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText(AppCopy.lastNameFirstNameNationalIDAndLicence)));
        return;
      }
    } else {
      if (_primaryDriver == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText(AppCopy.selectAMainDriver)));
        return;
      }
    }

    if (_hasSecondaryDriver && _isNewSecondaryDriver) {
      if (_newSecondaryFirstName.text.trim().isEmpty ||
          _newSecondaryLastName.text.trim().isEmpty ||
          _newSecondaryCin.text.trim().isEmpty ||
          _newSecondaryLicense.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                AppText(AppCopy.lastNameFirstNameNationalIDAndLicence40cf2a)));
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    // --- SMART VALIDATION ---
    final warnings = <String>[];

    // 1. Same driver check
    final pCin =
        _isNewPrimaryDriver ? _newPrimaryCin.text.trim() : _primaryDriver?.cin;
    final sCin = _hasSecondaryDriver
        ? (_isNewSecondaryDriver
            ? _newSecondaryCin.text.trim()
            : _secondaryDriver?.cin)
        : null;
    if (_hasSecondaryDriver &&
        pCin == sCin &&
        pCin != null &&
        pCin.isNotEmpty) {
      warnings.add(AppCopy.theMainAndAdditionalDriversAreTheSame);
    }

    // 2. License expiry check
    final pExpiry = _isNewPrimaryDriver
        ? _newPrimaryLicenseExpiry
        : _primaryDriver?.licenseExpiryDate;
    if (pExpiry != null && pExpiry.isBefore(DateTime.now())) {
      warnings.add(context.messages.mainLicenceExpired(
          (DateFormat('dd/MM/yyyy').format(pExpiry)).toString()));
    }

    final sExpiry = _hasSecondaryDriver
        ? (_isNewSecondaryDriver
            ? _newSecondaryLicenseExpiry
            : _secondaryDriver?.licenseExpiryDate)
        : null;
    if (sExpiry != null && sExpiry.isBefore(DateTime.now())) {
      warnings.add(context.messages.additionalLicenceExpired(
          (DateFormat('dd/MM/yyyy').format(sExpiry)).toString()));
    }

    if (warnings.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              AppText(AppCopy.warnings),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: warnings
                .map<Widget>((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AppText('• ${context.tr(w)}'),
                    ))
                .toList()
              ..add(const AppText(AppCopy.doYouStillWantToContinue)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText(AppCopy.cancele326f7),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText(AppCopy.continue71e092),
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
      final contractNumber =
          await ref.read(contractsProvider.notifier).generateContractNumber();
      final rawNow = DateTime.now();
      DateTime adjustedNow = rawNow;
      if (rawNow.hour >= 18) {
        adjustedNow = DateTime(rawNow.year, rawNow.month, rawNow.day, 18, 0);
      } else if (rawNow.hour < 8) {
        final prev = rawNow.subtract(const Duration(days: 1));
        adjustedNow = DateTime(prev.year, prev.month, prev.day, 18, 0);
      }
      final now = adjustedNow;

      int primaryId;
      if (_isNewPrimaryDriver) {
        final pCin = _newPrimaryCin.text.trim();
        final pLic = _newPrimaryLicense.text.trim();
        final pPhone = _newPrimaryPhone.text.trim();
        primaryId = await ref
            .read(clientsProvider.notifier)
            .createClientAndReturnId(ClientModel(
              firstName: _newPrimaryFirstName.text.trim(),
              lastName: _newPrimaryLastName.text.trim(),
              cin: pCin.isEmpty
                  ? 'NON_RENSEIGNE_${now.millisecondsSinceEpoch}'
                  : pCin,
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
          secondaryId = await ref
              .read(clientsProvider.notifier)
              .createClientAndReturnId(ClientModel(
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

      final contract = ContractModel(
        id: null,
        contractNumber: contractNumber,
        vehicleId: _selectedVehicle!.id!,
        primaryDriverId: primaryId,
        secondaryDriverId: secondaryId,
        chauffeurId: _chauffeur?.id,
        chauffeurHours: double.tryParse(_chauffeurHoursController.text) ?? 0,
        chauffeurHourlyRate: _chauffeur?.hourlyRate ?? 0,
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

      await ref.read(contractsProvider.notifier).addContract(
            contract,
            sourceReservationId: widget.reservation?.id,
          );
      await ref.read(dashboardProvider.notifier).refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText(AppStrings.successSaved)),
      );
      context.go('/contracts');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            context.trError(e),
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

  VehicleModel? _vehicleWithId(List<VehicleModel> vehicles, int? id) {
    if (id == null) return null;
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  ClientModel? _secondaryDropdownValue(List<ClientModel> clients) {
    final current = _secondaryDriver;
    if (current == null) return null;
    if (_primaryDriver != null && current.id == _primaryDriver!.id) return null;
    final filtered = _uniqueClients(clients, _secondaryClientSearchQuery).where(
      (c) => _primaryDriver == null || c.id != _primaryDriver!.id,
    );
    return _clientWithId(filtered.toList(), current.id);
  }

  void _setPaid(double value) {
    setState(() {
      _amountPaid = value;
      _amountPaidController.text = value == 0 ? '' : value.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final clientsAsync = ref.watch(clientsProvider);
    final chauffeurs =
        ref.watch(chauffeursProvider).value ?? const <ChauffeurModel>[];

    final sourceVehicleId = widget.reservation?.vehicleId;
    final availableVehicles = (vehiclesAsync.value ?? const <VehicleModel>[])
        .where((v) =>
            v.status == 'available' ||
            (v.id == sourceVehicleId && v.status != 'maintenance'))
        .toList();
    final showForm = vehiclesAsync.hasValue &&
        clientsAsync.hasValue &&
        availableVehicles.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const AppText(AppCopy.newContract),
      ),
      bottomNavigationBar: showForm ? _buildSubmitBar(context) : null,
      body: vehiclesAsync.when(
        data: (vehicles) {
          if (availableVehicles.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyStateWidget(
                title: AppCopy.noVehicleIsAvailable,
                subtitle: AppCopy.addAVehicleOrCloseAnExistingContract,
                icon: Icons.directions_car_filled_outlined,
                actionLabel: AppCopy.addAVehicle,
                onAction: () => context.push('/vehicles/add'),
              ),
            );
          }

          return clientsAsync.when(
            data: (clients) =>
                _buildForm(context, availableVehicles, clients, chauffeurs),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: AppText(
                context.trError(error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: AppText(
            context.trError(error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// Always-visible total and the submit button, so the operator never has to
  /// scroll to the end of a long form to finish it.
  Widget _buildSubmitBar(BuildContext context) {
    final theme = Theme.of(context);
    return BottomActionBar(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                    context.messages
                        .totalAmount((context.money(_totalPrice)).toString()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium),
                AppText(
                  _remaining <= 0.009
                      ? AppCopy.paidInFull
                      : context.messages.balanceAmount(
                          (context.money(_remaining)).toString()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _remaining <= 0.009
                        ? AppTone.success.color
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const AppText(AppCopy.createContract),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<VehicleModel> availableVehicles,
    List<ClientModel> clients,
    List<ChauffeurModel> chauffeurs,
  ) {
    final theme = Theme.of(context);
    final vehicle = _vehicleWithId(availableVehicles, _selectedVehicle?.id);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormSection(
                  step: 1,
                  title: AppCopy.vehicle,
                  subtitle: context.messages
                      .availableCount((availableVehicles.length).toString()),
                  children: [
                    DropdownButtonFormField<VehicleModel>(
                      isExpanded: true,
                      value: vehicle,
                      items: availableVehicles
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                '${v.brand} ${v.model} · ${v.registrationNumber}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedVehicle = v),
                      decoration: InputDecoration(
                        labelText: context.tr(AppCopy.chooseAVehicle),
                        prefixIcon: Icon(Icons.directions_car_outlined),
                      ),
                    ),
                    if (vehicle != null) _VehicleSummary(vehicle: vehicle),
                  ],
                ),
                const SizedBox(height: 16),
                FormSection(
                  step: 2,
                  title: AppCopy.clientMainDriver,
                  children: _driverFields(isPrimary: true, clients: clients),
                ),
                const SizedBox(height: 16),
                FormSection(
                  step: 3,
                  title: AppCopy.additionalDriver,
                  subtitle: AppCopy.optional,
                  trailing: Switch(
                    value: _hasSecondaryDriver,
                    onChanged: (v) => setState(() => _hasSecondaryDriver = v),
                  ),
                  children: _hasSecondaryDriver
                      ? _driverFields(isPrimary: false, clients: clients)
                      : const [],
                ),
                const SizedBox(height: 16),
                FormSection(
                  step: 4,
                  title: AppCopy.agencyDriver,
                  subtitle: AppCopy.optionalBilledHourly,
                  children: [
                    DropdownButtonFormField<ChauffeurModel?>(
                      isExpanded: true,
                      value: _chauffeur,
                      decoration: InputDecoration(
                        labelText: context.tr(AppCopy.driver),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<ChauffeurModel?>(
                            value: null, child: AppText(AppCopy.noDriver)),
                        ...chauffeurs
                            .where((c) => c.status == 'available')
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    '${c.fullName} — ${context.money(c.hourlyRate)}/h',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                      ],
                      onChanged: (value) => setState(() {
                        _chauffeur = value;
                        _updateTotalPrice();
                      }),
                    ),
                    if (_chauffeur != null)
                      TextFormField(
                        controller: _chauffeurHoursController,
                        decoration: InputDecoration(
                          labelText: context.tr(AppCopy.numberOfDriverHours),
                          suffixText: 'h',
                          prefixIcon: Icon(Icons.schedule),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(_updateTotalPrice),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FormSection(
                  step: 5,
                  title: AppCopy.rentalPeriod,
                  subtitle:
                      context.messages.durationDays((_rentalDays).toString()),
                  children: [
                    _DateField(
                      label: AppCopy.start,
                      value: _dateFormatter.format(_startDate),
                      onTap: _pickStartDate,
                    ),
                    _DateField(
                      label: AppCopy.expectedReturn,
                      value: _dateFormatter.format(_expectedReturnDate),
                      onTap: _pickExpectedReturnDate,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(AppCopy.quickDuration,
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final d in _allowedDurations)
                              ChoiceChip(
                                label: AppText(
                                    context.messages.dayShort((d).toString())),
                                selected: _durationDays == d,
                                onSelected: (_) {
                                  setState(() {
                                    _durationDays = _normalizeDurationDays(d);
                                    _expectedReturnDate = _startDate
                                        .add(Duration(days: _durationDays));
                                    _updateTotalPrice();
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FormSection(
                  step: 6,
                  title: AppCopy.payment,
                  children: [
                    TextFormField(
                      controller: _dailyPriceController,
                      decoration: InputDecoration(
                        labelText: context.tr(AppCopy.dailyPrice),
                        suffixText: 'MAD',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          _dailyPrice = double.tryParse(value) ?? 0;
                          _updateTotalPrice();
                        });
                      },
                    ),
                    TextFormField(
                      controller: _totalPriceController,
                      decoration: InputDecoration(
                        labelText: context.tr(AppCopy.contractTotal),
                        suffixText: 'MAD',
                        prefixIcon: Icon(Icons.calculate_outlined),
                        helperText: context.tr(AppCopy
                            .calculatedAutomaticallyYouCanEditItManually),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          _totalPrice = double.tryParse(value) ?? 0;
                          // Automatically update daily price if total price is set manually
                          if (_durationDays > 0 && value.isNotEmpty) {
                            _dailyPrice = _totalPrice / _durationDays;
                            _dailyPriceController.text =
                                _dailyPrice.toStringAsFixed(2);
                          }
                        });
                      },
                    ),
                    TextFormField(
                      controller: _amountPaidController,
                      decoration: InputDecoration(
                        labelText: context.tr(AppCopy.amountPaidNow),
                        suffixText: 'MAD',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          _amountPaid = double.tryParse(value) ?? 0;
                        });
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.done_all, size: 18),
                          label: const AppText(AppCopy.payAll),
                          onPressed: _totalPrice > 0
                              ? () => _setPaid(_totalPrice)
                              : null,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.money_off, size: 18),
                          label: const AppText(AppCopy.noDeposit),
                          onPressed: () => _setPaid(0),
                        ),
                      ],
                    ),
                    if (_remaining < -0.009)
                      const AlertBanner(
                        tone: AppTone.warning,
                        title: AppCopy.theAmountPaidExceedsTheTotal,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _driverFields({
    required bool isPrimary,
    required List<ClientModel> clients,
  }) {
    final isNew = isPrimary ? _isNewPrimaryDriver : _isNewSecondaryDriver;
    final firstName = isPrimary ? _newPrimaryFirstName : _newSecondaryFirstName;
    final lastName = isPrimary ? _newPrimaryLastName : _newSecondaryLastName;
    final cin = isPrimary ? _newPrimaryCin : _newSecondaryCin;
    final license = isPrimary ? _newPrimaryLicense : _newSecondaryLicense;
    final phone = isPrimary ? _newPrimaryPhone : _newSecondaryPhone;
    final selected = isPrimary ? _primaryDriver : _secondaryDriver;

    return [
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: AppText(AppCopy.existingClient)),
          ButtonSegment(value: true, label: AppText(AppCopy.newClient)),
        ],
        selected: {isNew},
        onSelectionChanged: (value) => setState(() {
          if (isPrimary) {
            _isNewPrimaryDriver = value.first;
          } else {
            _isNewSecondaryDriver = value.first;
          }
        }),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (isNew) ...[
            OutlinedButton.icon(
              onPressed: _isImportingOcr
                  ? null
                  : () => _importDriverOcr(
                      isPrimary: isPrimary, isPermis: false, clients: clients),
              icon: const Icon(Icons.document_scanner_outlined, size: 20),
              label: const AppText(AppCopy.scanNationalID),
            ),
            OutlinedButton.icon(
              onPressed: _isImportingOcr
                  ? null
                  : () => _importDriverOcr(
                      isPrimary: isPrimary, isPermis: true, clients: clients),
              icon: const Icon(Icons.credit_card, size: 20),
              label: const AppText(AppCopy.scanDrivingLicence),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: _isImportingOcr
                  ? null
                  : () => _importDriverOcr(
                      isPrimary: isPrimary, isPermis: false, clients: clients),
              icon: const Icon(Icons.document_scanner_outlined, size: 20),
              label: const AppText(AppCopy.findByScanningNationalID),
            ),
        ],
      ),
      if (_isImportingOcr)
        const LinearProgressIndicator()
      else if (isNew) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: firstName,
                textCapitalization: TextCapitalization.words,
                decoration:
                    InputDecoration(labelText: context.tr(AppCopy.firstName)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: lastName,
                textCapitalization: TextCapitalization.characters,
                decoration:
                    InputDecoration(labelText: context.tr(AppCopy.name)),
              ),
            ),
          ],
        ),
        TextFormField(
          controller: cin,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: context.tr('CIN'),
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        TextFormField(
          controller: license,
          decoration: InputDecoration(
            labelText: context.tr(AppCopy.drivingLicenceNumber),
            prefixIcon: Icon(Icons.credit_card),
          ),
        ),
        TextFormField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: context.tr(AppCopy.phoneOptional),
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
      ] else ...[
        TextFormField(
          decoration: InputDecoration(
            labelText: context.tr(isPrimary
                ? AppCopy.searchForAClient
                : AppCopy.searchForAnAdditionalDriver),
            hintText: context.tr(AppCopy.nameOrNationalID),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              if (isPrimary) {
                _clientSearchQuery = value;
                _syncSelectedDriversWithFilter(clients);
              } else {
                _secondaryClientSearchQuery = value;
                final filtered =
                    _uniqueClients(clients, _secondaryClientSearchQuery);
                if (_secondaryDriver != null &&
                    !filtered.any((c) => c.id == _secondaryDriver!.id)) {
                  _secondaryDriver = null;
                }
              }
            });
          },
        ),
        if (isPrimary)
          DropdownButtonFormField<ClientModel>(
            isExpanded: true,
            value: _clientWithId(
              _uniqueClients(clients, _clientSearchQuery),
              _primaryDriver?.id,
            ),
            items: _uniqueClients(clients, _clientSearchQuery)
                .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c.fullName} (${c.cin})',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (c) {
              setState(() {
                _primaryDriver = c;
                if (c != null && _secondaryDriver?.id == c.id) {
                  _secondaryDriver = null;
                }
              });
            },
            decoration:
                InputDecoration(labelText: context.tr(AppCopy.chooseAClient)),
          )
        else
          DropdownButtonFormField<ClientModel?>(
            isExpanded: true,
            value: _secondaryDropdownValue(clients),
            items: [
              const DropdownMenuItem<ClientModel?>(
                  value: null, child: AppText(AppCopy.none)),
              ..._uniqueClients(clients, _secondaryClientSearchQuery)
                  .where((c) =>
                      _primaryDriver == null || c.id != _primaryDriver!.id)
                  .map((c) => DropdownMenuItem<ClientModel?>(
                      value: c,
                      child: Text('${c.fullName} (${c.cin})',
                          overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (ClientModel? c) => setState(() => _secondaryDriver = c),
            decoration: InputDecoration(
                labelText: context.tr(AppCopy.additionalDriver)),
          ),
        if (selected != null) _ClientHint(client: selected),
      ],
    ];
  }
}

class _VehicleSummary extends StatelessWidget {
  const _VehicleSummary({required this.vehicle});
  final VehicleModel vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 56,
            child: VehiclePhoto(vehicle: vehicle, iconSize: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlateBadge(vehicle.registrationNumber),
                const SizedBox(height: 6),
                AppText(
                  '${context.distance(vehicle.currentMileage)} · '
                  '${context.tr(fuelTypeName(vehicle.fuelType))} ${vehicle.fuelLevel} %',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                StatusChip(
                  label: conditionName(vehicle.conditionStatus),
                  tone: conditionTone(vehicle.conditionStatus),
                  icon: conditionIcon(vehicle.conditionStatus),
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Flags an expired licence as soon as the client is picked, rather than only
/// in the confirmation dialog at the very end.
class _ClientHint extends StatelessWidget {
  const _ClientHint({required this.client});
  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    final licence = expiryOf(client.licenseExpiryDate);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(
            label: client.phone, icon: Icons.phone_outlined, dense: true),
        if (client.licenseExpiryDate != null)
          StatusChip(
            label: context.messages
                .licenceStatus(context.tr((licence.label).toString())),
            tone: licence.tone,
            icon: Icons.credit_card,
            dense: true,
          ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.tr(label),
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: const Icon(Icons.edit_calendar_outlined),
        ),
        child: AppText(value,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
