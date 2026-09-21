import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/license/license_manager.dart';
import '../../../core/notifications/notification_preferences.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../data/models/license_model.dart';
import '../../../core/storage/media_store.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../widgets/common/alert_banner.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/detail_row.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/motion/motion.dart';
import '../../widgets/common/recovery_code_view.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AmbientController _ambient = AmbientController(vsync: this);
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _licenseKeyController = TextEditingController();

  final LicenseManager _licenseManager = LicenseManager();

  bool _loadingLicense = true;
  bool _licenseValid = false;
  LicenseData? _licenseData;
  String? _licenseInfo;
  String? _deviceId;
  bool _savingCompany = false;
  bool _backupInProgress = false;

  String _logoPath = '';
  String _signaturePath = '';
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  int _autoLockMinutes = AuthRepository.defaultAutoLockMinutes;

  NotificationPreferences _notifications = const NotificationPreferences();
  bool _notificationsGranted = false;
  NotificationDiagnostics? _notificationStatus;

  @override
  void initState() {
    super.initState();
    _loadLicenseInfo();
    _loadCompanySettings();
    _loadAuthSettings();
    _loadNotificationSettings();
  }

  Future<void> _loadAuthSettings() async {
    final auth = ref.read(authRepositoryProvider);
    final available = await auth.biometricAvailable();
    final enabled = await auth.biometricEnabled();
    final minutes = await auth.autoLockMinutes();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _autoLockMinutes = minutes;
    });
  }

  Future<void> _setBiometric(bool value) async {
    final auth = ref.read(authRepositoryProvider);

    // Confirm the sensor actually works for this user before promising it on
    // the lock screen; enrolment can be missing or fail silently.
    if (value) {
      final ok = await auth.authenticateWithBiometrics(
        reason: 'Confirmez pour activer le déverrouillage biométrique',
      );
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biométrie non confirmée. Option non activée.'),
            ),
          );
        }
        return;
      }
    }

    await auth.setBiometricEnabled(value);
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
    await ref.read(authProvider.notifier).refresh();
  }

  Future<void> _loadNotificationSettings() async {
    final preferences = await NotificationPreferencesRepository.instance.load();
    final status = await NotificationService.instance.diagnostics();
    if (!mounted) return;
    setState(() {
      _notifications = preferences;
      _notificationsGranted = status.notificationsAllowed;
      _notificationStatus = status;
    });
  }

  Future<void> _fixPermissions() async {
    await NotificationService.instance.requestPermission();
    await _loadNotificationSettings();
    if (!mounted) return;
    final status = _notificationStatus;
    if (status != null && !status.isFullyGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Certaines autorisations sont encore refusées. '
            'Ouvrez les réglages Android de l\'application.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  /// Says in plain words whether reminders will actually reach the operator,
  /// and offers the one button that fixes it.
  Widget _buildNotificationStatus(ThemeData theme) {
    final status = _notificationStatus;
    if (status == null) return const LinearProgressIndicator();
    if (!status.available) {
      return const AlertBanner(
        tone: AppTone.neutral,
        title: 'Rappels indisponibles',
        message: 'Cette plateforme ne gère pas les rappels locaux.',
      );
    }
    if (!status.notificationsAllowed) {
      return AlertBanner(
        tone: AppTone.danger,
        title: 'Notifications bloquées par Android',
        message: 'Aucun rappel ne s’affichera : ni retours de véhicules, '
            'ni paiements. Autorisez les notifications pour cette application.',
        actionLabel: 'Autoriser les notifications',
        onAction: _fixPermissions,
      );
    }
    if (!status.exactAlarmsAllowed) {
      return AlertBanner(
        tone: AppTone.warning,
        title: 'Rappels possiblement en retard',
        message: 'Sans l’autorisation « Alarmes et rappels », Android peut '
            'retarder un rappel de 14h37 jusqu’au prochain réveil du téléphone.',
        actionLabel: 'Autoriser les alarmes exactes',
        onAction: _fixPermissions,
      );
    }
    return AlertBanner(
      tone: AppTone.success,
      title: 'Les rappels fonctionnent',
      message: status.pending == 0
          ? 'Aucun rappel en attente : aucun contrat en cours à venir.'
          : '${status.pending} rappel(s) programmé(s).',
    );
  }

  Future<void> _updateNotifications(NotificationPreferences updated) async {
    // Turning reminders on is worthless if the OS is dropping them, so ask for
    // the permission at the moment the user shows they want them.
    if (updated.enabled && !_notificationsGranted) {
      final granted = await NotificationService.instance.requestPermission();
      if (!mounted) return;
      setState(() => _notificationsGranted = granted);
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Les notifications sont bloquées pour cette application. '
              'Activez-les dans les réglages Android.',
            ),
          ),
        );
        return;
      }
    }

    await NotificationPreferencesRepository.instance.save(updated);
    if (!mounted) return;
    setState(() => _notifications = updated);

    // Turning everything off should silence what is already scheduled, not
    // just stop new reminders being added.
    if (!updated.enabled) {
      await NotificationService.instance.cancelAll();
    } else {
      await _rearmAllReminders();
    }
  }

  /// Re-schedules every active contract under the new preferences.
  Future<void> _rearmAllReminders() async {
    final contracts = ref.read(contractsProvider).value ?? const [];
    final notifier = ref.read(contractsProvider.notifier);
    for (final contract in contracts.where((c) => c.status == 'active')) {
      await notifier.syncReminders(contract);
    }
  }

  Future<void> _pickLeadTime() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Prévenir avant l\'échéance'),
        children: [
          for (final minutes in NotificationPreferencesRepository.leadChoices)
            RadioListTile<int>(
              value: minutes,
              groupValue: _notifications.leadMinutes,
              title: Text(_leadLabel(minutes)),
              onChanged: (value) => Navigator.pop(context, value),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await _updateNotifications(_notifications.copyWith(leadMinutes: picked));
  }

  static String _leadLabel(int minutes) {
    if (minutes >= 1440) return '1 jour avant';
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      return '$hours heure${hours > 1 ? 's' : ''} avant';
    }
    return '$minutes minutes avant';
  }

  Future<void> _pickQuietHour({required bool isStart}) async {
    final current =
        isStart ? _notifications.quietStartHour : _notifications.quietEndHour;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current, minute: 0),
      helpText: isStart ? 'Début du silence' : 'Fin du silence',
    );
    if (picked == null) return;
    await _updateNotifications(
      isStart
          ? _notifications.copyWith(quietStartHour: picked.hour)
          : _notifications.copyWith(quietEndHour: picked.hour),
    );
  }

  static String _formatHour(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00';

  Widget _buildNotificationSettings(ThemeData theme) {
    final enabled = _notifications.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNotificationStatus(theme),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Rappels de retour'),
                subtitle: const Text(
                    'Retours prévus, véhicules en retard, paiements.'),
                value: enabled,
                onChanged: (value) => _updateNotifications(
                    _notifications.copyWith(enabled: value)),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: !enabled
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        children: [
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.schedule),
                            title: const Text('Prévenir avant l\'échéance'),
                            subtitle:
                                Text(_leadLabel(_notifications.leadMinutes)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _pickLeadTime,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.payments_outlined),
                            title: const Text('Rappels de paiement'),
                            subtitle: const Text(
                                'Quand un solde reste dû à l\'échéance.'),
                            value: _notifications.paymentReminders,
                            onChanged: (value) => _updateNotifications(
                              _notifications.copyWith(paymentReminders: value),
                            ),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.vpn_key_outlined),
                            title: const Text('Expiration de la licence'),
                            subtitle: const Text('Alertes à 30, 7 et 1 jour.'),
                            value: _notifications.licenseAlerts,
                            onChanged: (value) => _updateNotifications(
                              _notifications.copyWith(licenseAlerts: value),
                            ),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.bedtime_outlined),
                            title: const Text('Heures silencieuses'),
                            subtitle: Text(
                              _notifications.quietHoursEnabled
                                  ? 'De ${_formatHour(_notifications.quietStartHour)} à ${_formatHour(_notifications.quietEndHour)} : reporté au matin.'
                                  : 'Les rappels peuvent sonner la nuit.',
                            ),
                            value: _notifications.quietHoursEnabled,
                            onChanged: (value) => _updateNotifications(
                              _notifications.copyWith(quietHoursEnabled: value),
                            ),
                          ),
                          if (_notifications.quietHoursEnabled)
                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    title: const Text('De'),
                                    subtitle: Text(_formatHour(
                                        _notifications.quietStartHour)),
                                    onTap: () => _pickQuietHour(isStart: true),
                                  ),
                                ),
                                Expanded(
                                  child: ListTile(
                                    title: const Text('À'),
                                    subtitle: Text(_formatHour(
                                        _notifications.quietEndHour)),
                                    onTap: () => _pickQuietHour(isStart: false),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The stored code is only a hash, so there is nothing to show again. What
  /// the user can always do is mint a fresh one while they are still inside —
  /// which is what keeps "I lost the paper" from being a dead end.
  Future<void> _regenerateRecoveryCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau code de récupération'),
        content: const Text(
          'Un nouveau code sera généré et affiché une seule fois. '
          'Votre code actuel cessera immédiatement de fonctionner.\n\n'
          'Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Générer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final code = await ref.read(authProvider.notifier).regenerateRecoveryCode();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      // Dismissing by tapping outside would lose the code for good.
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: RecoveryCodeView(
              code: code,
              acknowledgeLabel: 'J\'ai noté ce code',
              onAcknowledged: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  static String _autoLockLabel(int minutes) {
    if (minutes <= 0) return 'Immédiatement';
    if (minutes == 1) return 'Après 1 minute en arrière-plan';
    return 'Après $minutes minutes en arrière-plan';
  }

  Future<void> _pickAutoLockDelay() async {
    const choices = <int>[0, 1, 5, 15];
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Verrouillage automatique'),
        children: [
          for (final minutes in choices)
            RadioListTile<int>(
              value: minutes,
              groupValue: _autoLockMinutes,
              title: Text(_autoLockLabel(minutes)),
              // "Immédiatement" also fires when the camera or the file picker
              // takes over the screen, which interrupts an OCR scan.
              subtitle: minutes == 0
                  ? const Text(
                      'Redemande le code après chaque scan de document.')
                  : null,
              onChanged: (value) => Navigator.pop(context, value),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    await ref.read(authRepositoryProvider).setAutoLockMinutes(picked);
    if (mounted) setState(() => _autoLockMinutes = picked);
  }

  Future<void> _createBackup() async {
    if (_backupInProgress) return;
    setState(() => _backupInProgress = true);
    try {
      final backup = await BackupService.instance.createBackup();
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(backup.path)],
        subject: 'Sauvegarde CarRent',
        text: 'Sauvegarde CarRent Manager',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Sauvegarde créée. Enregistrez le fichier ZIP dans un endroit sûr.'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sauvegarde impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _backupInProgress = false);
    }
  }

  Future<void> _restoreBackup() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    final path = selected?.files.singleOrNull?.path;
    if (path == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: const Text(
          'Les données et documents actuels de cette application seront remplacés. '
          'Le code PIN et la licence de ce téléphone resteront en place.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _backupInProgress = true);
    try {
      // Pending Android alarms belong to the old database. Clear them after
      // the ZIP has passed validation, then schedule restored active contracts.
      await BackupService.instance.restoreBackup(
        File(path),
        beforeReplace: NotificationService.instance.cancelAll,
      );

      ref.invalidate(vehiclesProvider);
      ref.invalidate(clientsProvider);
      ref.invalidate(contractsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(companyNameProvider);
      ref.invalidate(companyAddressProvider);
      ref.invalidate(companyPhoneProvider);
      ref.invalidate(companyLogoProvider);
      ref.invalidate(companySignatureProvider);
      await ref.read(contractsProvider.notifier).restoreReminders();
      await ref.read(authProvider.notifier).refresh();
      await _loadCompanySettings();
      await _loadNotificationSettings();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sauvegarde restaurée. Les rappels ont été recréés.'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restauration impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _backupInProgress = false);
    }
  }

  Widget _buildBackupSettings() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Créer une sauvegarde'),
            subtitle:
                const Text('Un fichier ZIP avec les données et les documents. '
                    'Gardez-le hors du téléphone.'),
            trailing: _backupInProgress
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _backupInProgress ? null : _createBackup,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restaurer une sauvegarde'),
            subtitle: const Text(
                'Remplace les données actuelles par celles du fichier ZIP.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _backupInProgress ? null : _restoreBackup,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ambient.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanySettings() async {
    final repo = AppSettingsRepository.instance;
    _companyNameController.text = await repo.getCompanyName();
    _companyAddressController.text = await repo.getCompanyAddress();
    _companyPhoneController.text = await repo.getCompanyPhone();
    _logoPath = await repo.getCompanyLogo();
    _signaturePath = await repo.getCompanySignature();
    if (mounted) setState(() {});
  }

  Future<void> _saveCompanySettings() async {
    if (_savingCompany) return;
    setState(() => _savingCompany = true);
    try {
      final repo = AppSettingsRepository.instance;
      await repo.setCompanyName(_companyNameController.text.trim());
      await repo.setCompanyAddress(_companyAddressController.text.trim());
      await repo.setCompanyPhone(_companyPhoneController.text.trim());
      await repo.setCompanyLogo(_logoPath);
      await repo.setCompanySignature(_signaturePath);

      ref.invalidate(companyNameProvider);
      ref.invalidate(companyAddressProvider);
      ref.invalidate(companyPhoneProvider);
      ref.invalidate(companyLogoProvider);
      ref.invalidate(companySignatureProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingCompany = false);
    }
  }

  Future<void> _loadLicenseInfo() async {
    setState(() => _loadingLicense = true);
    try {
      final result = await _licenseManager.validateRuntime();
      final deviceId = await _licenseManager.getDeviceId();
      if (!mounted) return;
      setState(() {
        _licenseValid = result.isValid;
        _licenseData = result.data;
        _licenseInfo = result.isValid ? null : result.error;
        _deviceId = deviceId;
        _loadingLicense = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _licenseValid = false;
        _licenseInfo = 'Erreur: $e';
        _loadingLicense = false;
      });
    }
  }

  Future<void> _saveLicense() async {
    final key = _licenseKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La clé de licence est requise.\nمطلوب مفتاح الترخيص.',
          ),
        ),
      );
      return;
    }
    try {
      await _licenseManager.saveLicense(key);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
      await _loadLicenseInfo();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l\'enregistrement de la licence.\n'
            'حدث خطأ أثناء حفظ الرخصة.\n'
            'License save error: $e',
          ),
        ),
      );
    }
  }

  Future<void> _pickImage(bool isLogo) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    // The picker hands back a copy in the app cache, which Android reclaims at
    // will. Left as-is the logo vanished from the settings screen and, worse,
    // silently dropped out of every generated contract PDF.
    final stored = await MediaStore.instance.save(
      File(path),
      prefix: isLogo ? 'logo' : 'signature',
    );
    if (!mounted) return;

    setState(() {
      if (isLogo) {
        _logoPath = stored;
      } else {
        _signaturePath = stored;
      }
    });
  }

  /// Shows who the licence belongs to, when it runs out, and this device's ID.
  /// Previously this was just "Licence active", which left no way to tell when
  /// a renewal was due or which device a new key had to be issued for.
  Widget _buildLicenseStatus(ThemeData theme) {
    if (!_licenseValid) {
      return AlertBanner(
        tone: AppTone.danger,
        title: 'Licence inactive',
        message: _licenseInfo ?? 'Aucune licence valide sur cet appareil.',
      );
    }

    final data = _licenseData;
    final expiry = data?.expiryDate;
    final daysLeft =
        expiry == null ? null : expiry.difference(DateTime.now()).inDays;
    // Warn while there is still time to obtain a new key.
    final expiringSoon = daysLeft != null && daysLeft <= 30;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DetailList(children: [
        DetailRow(
          icon: Icons.verified_user_outlined,
          label: 'État',
          value: expiringSoon ? 'Expire bientôt' : 'Licence active',
          trailing: StatusChip(
            label: expiringSoon ? '$daysLeft j restants' : 'Valide',
            tone: expiringSoon ? AppTone.warning : AppTone.success,
            icon: expiringSoon ? Icons.warning_amber_rounded : Icons.check,
            dense: true,
          ),
        ),
        if (data != null && data.name.isNotEmpty)
          DetailRow(
              icon: Icons.business_outlined,
              label: 'Licencié à',
              value: data.name),
        if (expiry != null)
          DetailRow(
              icon: Icons.event_outlined,
              label: 'Expire le',
              value: formatDate(expiry)),
        if (_deviceId != null)
          DetailRow(
            icon: Icons.smartphone_outlined,
            label: 'ID de cet appareil',
            value: _deviceId!,
            mono: true,
            trailing: const Icon(Icons.copy_outlined,
                size: 18, color: AppColors.textSecondary),
            onTap: () {
              Clipboard.setData(ClipboardData(text: _deviceId!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID de l\'appareil copié !')),
              );
            },
          ),
      ]),
    );
  }

  Widget _buildImagePicker(String label, String path, bool isLogo) {
    final file = MediaStore.instance.resolveFile(path);
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: file != null
              ? Image.file(file, fit: BoxFit.cover)
              : const Icon(Icons.image_outlined,
                  color: AppColors.textSecondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _pickImage(isLogo),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.upload_file, size: 20),
                label: Text(file == null ? 'Ajouter' : 'Changer'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _group(String title, Widget child, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        ),
        child,
      ],
    );
  }

  Widget _navRow(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final companyName = _companyNameController.text.trim();
    final notificationsOk = _notificationStatus?.isFullyGranted ?? true;
    final top = MediaQuery.paddingOf(context).top;
    final expanded = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(240.0, 320.0)
        .toDouble();
    final collapsed = top + kToolbarHeight;

    final items = <Widget>[
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              companyName.isEmpty ? 'CarRent Manager' : companyName,
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  label: _loadingLicense
                      ? 'Licence…'
                      : _licenseValid
                          ? 'Licence active'
                          : 'Licence inactive',
                  tone: _licenseValid ? AppTone.success : AppTone.danger,
                  icon: _licenseValid
                      ? Icons.verified_user_outlined
                      : Icons.error_outline,
                ),
                StatusChip(
                  label:
                      notificationsOk ? 'Rappels actifs' : 'Rappels à corriger',
                  tone: notificationsOk ? AppTone.success : AppTone.warning,
                  icon: notificationsOk
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
      _group(
        'Mon agence',
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(Icons.business_outlined),
                  title: const Text('Informations de la société'),
                  subtitle: const Text(
                      'Nom, adresse, logo et signature sur les contrats.'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    TextField(
                      controller: _companyNameController,
                      decoration:
                          const InputDecoration(labelText: 'Nom de la société'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _companyAddressController,
                      decoration: const InputDecoration(labelText: 'Adresse'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _companyPhoneController,
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildImagePicker('Logo de la société', _logoPath, true),
                    const SizedBox(height: 12),
                    _buildImagePicker(
                        'Signature de l\'agence', _signaturePath, false),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _savingCompany ? null : _saveCompanySettings,
                      icon: _savingCompany
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _navRow(
                  Icons.badge_outlined,
                  'Chauffeurs',
                  'Gérer les chauffeurs, leur prix par heure et leur disponibilité.',
                  () => context.push('/chauffeurs')),
              const Divider(height: 1),
              _navRow(
                  Icons.auto_awesome_outlined,
                  'Assistant local',
                  'Questions sur l’agence, hors ligne : le modèle reste sur le téléphone.',
                  () => context.push('/assistant')),
            ],
          ),
        ),
      ),
      _group(
        'Rappels',
        _buildNotificationSettings(theme),
        subtitle: 'Retours, paiements et licence.',
      ),
      _group(
        'Sauvegarde',
        _buildBackupSettings(),
        subtitle: 'Protégez vos données si le téléphone est perdu.',
      ),
      _group(
        'Licence',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadingLicense)
              const LinearProgressIndicator()
            else
              _buildLicenseStatus(theme),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: const Text('Renouveler la licence'),
                  subtitle: const Text(
                      'Seulement pour prolonger ou après un changement d’appareil.'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    TextField(
                      controller: _licenseKeyController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Nouvelle clé de licence',
                        hintText:
                            'Collez ici la clé fournie par votre fournisseur',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saveLicense,
                      icon: const Icon(Icons.vpn_key),
                      label: const Text('Appliquer la nouvelle clé'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      _group(
        'Sécurité',
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              _navRow(
                  Icons.pin_outlined,
                  'Modifier le code PIN',
                  'Demande le code actuel avant tout changement.',
                  () => context.push('/settings/pin')),
              const Divider(height: 1),
              _navRow(
                  Icons.vpn_key_outlined,
                  'Code de récupération',
                  'Générer un nouveau code. L\'ancien sera annulé.',
                  _regenerateRecoveryCode),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Déverrouillage biométrique'),
                subtitle: Text(
                  _biometricAvailable
                      ? 'Utiliser l\'empreinte ou le visage à la place du code.'
                      : 'Aucune empreinte enregistrée sur cet appareil.',
                ),
                value: _biometricEnabled && _biometricAvailable,
                onChanged: _biometricAvailable ? _setBiometric : null,
              ),
              const Divider(height: 1),
              _navRow(Icons.timer_outlined, 'Verrouillage automatique',
                  _autoLockLabel(_autoLockMinutes), _pickAutoLockDelay),
            ],
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: () => ref.read(authProvider.notifier).lock(),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTone.danger.color,
          side: BorderSide(color: AppTone.danger.color),
        ),
        icon: const Icon(Icons.lock_outline),
        label: const Text('Verrouiller maintenant'),
      ),
    ];

    return Scaffold(
      body: AmbientListener(
        controller: _ambient,
        child: Stack(
          children: [
            // The wide artwork stays behind the whole page, sliding across as
            // you scroll, so nothing ever falls back to a flat colour.
            Positioned.fill(
              child: AmbientImage(
                controller: _ambient,
                asset: 'assets/backgrounds/bg_body.webp',
                zoom: 1.0,
                panFrom: const Alignment(-0.6, 0),
                panTo: const Alignment(0.75, 0.1),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.background.withValues(alpha: 0.22),
              ),
            ),
            CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: HeroHeaderDelegate(
                    asset: 'assets/backgrounds/bg_settings.webp',
                    title: 'Paramètres',
                    showTitle: false,
                    expanded: expanded,
                    collapsed: collapsed,
                    topPadding: top,
                    controller: _ambient,
                    // Starts on the logo; scrolling pans down to the tagline.
                    startAlignment: const Alignment(0, -0.05),
                    endAlignment: const Alignment(-0.2, 0.95),
                    foreground: AppColors.textPrimary,
                    scrim: AppColors.background,
                    scrimStrength: 0,
                    fadeBottom: true,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/dashboard'),
                      tooltip: 'Retour au tableau de bord',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: AnimatedTitle(
                      eyebrow: 'Votre agence',
                      title: 'Paramètres',
                      subtitle: companyName.isEmpty ? null : companyName,
                    ),
                  ),
                ),
                SliverPadding(
                  // Pad past the system navigation bar so the last control is
                  // not trapped under the phone's back/home buttons.
                  padding: EdgeInsets.fromLTRB(16, 12, 16,
                      24 + MediaQuery.viewPaddingOf(context).bottom),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) => Reveal(
                      index: i,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: Padding(
                            padding: EdgeInsets.only(
                                top: i == items.length - 1 ? 24 : 0),
                            child: items[i],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: AmbientGlints(controller: _ambient),
            ),
            Positioned(
              right: 2,
              top: 0,
              bottom: 0,
              child: Center(child: ScrollRail(controller: _ambient)),
            ),
          ],
        ),
      ),
    );
  }
}
