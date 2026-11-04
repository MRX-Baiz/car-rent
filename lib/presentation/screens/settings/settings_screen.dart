import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/license/license_features.dart';
import '../../../core/license/license_manager.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/license_model.dart';
import '../../../core/storage/media_store.dart';
import '../../../domain/entities/company_profile.dart';
import '../../../domain/entities/notification_diagnostics.dart';
import '../../../domain/entities/notification_preferences.dart';
import '../../../domain/entities/reminder_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../widgets/common/alert_banner.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/detail_row.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/layout/app_page.dart';
import '../../widgets/common/recovery_code_view.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
  int _autoLockMinutes = defaultAppAutoLockMinutes;

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
    final auth = await ref.read(authProvider.notifier).loadSecuritySettings();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = auth.available;
      _biometricEnabled = auth.enabled;
      _autoLockMinutes = auth.autoLockMinutes;
    });
  }

  Future<void> _setBiometric(bool value) async {
    final changed = await ref.read(authProvider.notifier).setBiometricEnabled(
          enabled: value,
          confirmationReason:
              context.tr(AppCopy.confirmToEnableBiometricUnlocking),
        );
    if (!changed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(AppCopy.biometricsNotConfirmedOptionNotEnabled),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
  }

  Future<void> _loadNotificationSettings() async {
    final settings = await ref.read(loadReminderSettingsProvider)();
    if (!mounted) return;
    _applyReminderSettings(settings);
  }

  void _applyReminderSettings(ReminderSettings settings) {
    setState(() {
      _notifications = settings.preferences;
      _notificationsGranted = settings.status.notificationsAllowed;
      _notificationStatus = settings.status;
    });
  }

  Future<void> _fixPermissions() async {
    final settings = await ref.read(requestReminderPermissionsProvider)();
    if (!mounted) return;
    _applyReminderSettings(settings);
    if (!settings.status.isFullyGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            AppCopy.somePermissionsAreStillDeniedOpenThisApp,
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
        title: AppCopy.remindersUnavailable,
        message: AppCopy.thisPlatformDoesNotSupportLocalReminders,
      );
    }
    if (!status.notificationsAllowed) {
      return AlertBanner(
        tone: AppTone.danger,
        title: AppCopy.notificationsBlockedByAndroid,
        message: AppCopy.noReturnOrPaymentRemindersWillAppearAllow,
        actionLabel: AppCopy.allowNotifications,
        onAction: _fixPermissions,
      );
    }
    if (!status.exactAlarmsAllowed) {
      return AlertBanner(
        tone: AppTone.warning,
        title: AppCopy.remindersMayBeDelayed,
        message: AppCopy.withoutTheAlarmsAndRemindersPermissionAndroidMay,
        actionLabel: AppCopy.allowExactAlarms,
        onAction: _fixPermissions,
      );
    }
    return AlertBanner(
      tone: AppTone.success,
      title: AppCopy.remindersAreWorking,
      message: status.pending == 0
          ? AppCopy.noPendingRemindersThereAreNoUpcomingActive
          : context.messages
              .scheduledReminderCount((status.pending).toString()),
    );
  }

  Future<void> _updateNotifications(NotificationPreferences updated) async {
    final result = await ref.read(changeReminderPreferencesProvider)(
      updated,
      permissionGranted: _notificationsGranted,
    );
    if (!mounted) return;
    setState(() => _notificationsGranted = result.permissionGranted);
    if (!result.saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            AppCopy.notificationsAreBlockedForThisAppEnableThem,
          ),
        ),
      );
      return;
    }
    setState(() => _notifications = updated);
  }

  Future<void> _pickLeadTime() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const AppText(AppCopy.notifyBeforeTheDeadline),
        children: [
          RadioGroup<int>(
            groupValue: _notifications.leadMinutes,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final minutes in NotificationPreferences.leadChoices)
                  RadioListTile<int>(
                    value: minutes,
                    title: AppText(_leadLabel(minutes)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await _updateNotifications(_notifications.copyWith(leadMinutes: picked));
  }

  String _leadLabel(int minutes) {
    if (minutes >= 1440) return AppCopy.message1DayBefore;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      return context.messages.leadHours((hours).toString());
    }
    return context.messages.leadMinutes((minutes).toString());
  }

  Future<void> _pickQuietHour({required bool isStart}) async {
    final current =
        isStart ? _notifications.quietStartHour : _notifications.quietEndHour;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current, minute: 0),
      helpText: isStart
          ? context.tr(AppCopy.quietHoursStart)
          : context.tr(AppCopy.quietHoursEnd),
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
                title: const AppText(AppCopy.returnReminders),
                subtitle:
                    const AppText(AppCopy.scheduledReturnsLateVehiclesPayments),
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
                            title:
                                const AppText(AppCopy.notifyBeforeTheDeadline),
                            subtitle:
                                AppText(_leadLabel(_notifications.leadMinutes)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _pickLeadTime,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.payments_outlined),
                            title: const AppText(AppCopy.paymentReminders),
                            subtitle: const AppText(
                                AppCopy.whenABalanceRemainsDueAtTheDeadline),
                            value: _notifications.paymentReminders,
                            onChanged: (value) => _updateNotifications(
                              _notifications.copyWith(paymentReminders: value),
                            ),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.vpn_key_outlined),
                            title: const AppText(AppCopy.licenceExpiry70b960),
                            subtitle:
                                const AppText(AppCopy.alertsAt307And1Days),
                            value: _notifications.licenseAlerts,
                            onChanged: (value) => _updateNotifications(
                              _notifications.copyWith(licenseAlerts: value),
                            ),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.bedtime_outlined),
                            title: const AppText(AppCopy.quietHours),
                            subtitle: AppText(
                              _notifications.quietHoursEnabled
                                  ? context.messages.quietHoursSummary(
                                      (_formatHour(
                                              _notifications.quietStartHour))
                                          .toString(),
                                      (_formatHour(_notifications.quietEndHour))
                                          .toString())
                                  : AppCopy.remindersMaySoundDuringTheNight,
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
                                    title: const AppText(AppCopy.from),
                                    subtitle: AppText(_formatHour(
                                        _notifications.quietStartHour)),
                                    onTap: () => _pickQuietHour(isStart: true),
                                  ),
                                ),
                                Expanded(
                                  child: ListTile(
                                    title: const AppText(AppCopy.to),
                                    subtitle: AppText(_formatHour(
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
        title: const AppText(AppCopy.newRecoveryCode),
        content: const AppText(
          AppCopy.aNewCodeWillBeGeneratedAndShown,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText(AppCopy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText(AppCopy.generate),
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
              acknowledgeLabel: AppCopy.iNotedThisCode,
              onAcknowledged: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  String _autoLockLabel(int minutes) {
    if (minutes <= 0) return AppCopy.immediately;
    if (minutes == 1) return AppCopy.after1MinuteInTheBackground;
    return context.messages.lockDelayMinutes((minutes).toString());
  }

  Future<void> _pickAutoLockDelay() async {
    const choices = <int>[0, 1, 5, 15];
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const AppText(AppCopy.automaticLock),
        children: [
          RadioGroup<int>(
            groupValue: _autoLockMinutes,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final minutes in choices)
                  RadioListTile<int>(
                    value: minutes,
                    title: AppText(_autoLockLabel(minutes)),
                    // "Immédiatement" also fires when the camera or the file picker
                    // takes over the screen, which interrupts an OCR scan.
                    subtitle: minutes == 0
                        ? const AppText(
                            AppCopy.askForThePINAgainAfterEachDocument)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    await ref.read(authProvider.notifier).setAutoLockMinutes(picked);
    if (mounted) setState(() => _autoLockMinutes = picked);
  }

  Future<void> _createBackup() async {
    if (_backupInProgress) return;
    setState(() => _backupInProgress = true);
    try {
      final backup = await ref.read(createBackupProvider)();
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(backup.path)],
        subject: context.tr(AppCopy.carrentBackup),
        text: context.tr(AppCopy.carrentManagerBackup),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(AppCopy.backupCreatedSaveTheZIPFileSomewhereSafe),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(context.trError(error))),
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
        title: const AppText(AppCopy.restoreThisBackup),
        content: const AppText(
          AppCopy.theAppSCurrentDataAndDocumentsWill,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText(AppCopy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText(AppCopy.restore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _backupInProgress = true);
    try {
      await ref.read(restoreBackupProvider)(path);

      ref.invalidate(vehiclesProvider);
      ref.invalidate(clientsProvider);
      ref.invalidate(contractsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(companyNameProvider);
      ref.invalidate(companyAddressProvider);
      ref.invalidate(companyPhoneProvider);
      ref.invalidate(companyLogoProvider);
      ref.invalidate(companySignatureProvider);
      await ref.read(authProvider.notifier).refresh();
      await _loadCompanySettings();
      await _loadNotificationSettings();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(AppCopy.backupRestoredRemindersWereRecreated),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(context.trError(error))),
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
            title: const AppText(AppCopy.createABackup),
            subtitle:
                const AppText(AppCopy.aZIPFileContainingYourDataAndDocuments),
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
            title: const AppText(AppCopy.restoreABackup),
            subtitle: const AppText(AppCopy.replaceCurrentDataWithTheDataInA),
            trailing: const Icon(Icons.chevron_right),
            onTap: _backupInProgress ? null : _restoreBackup,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanySettings() async {
    final profile = await ref.read(loadCompanyProfileProvider)();
    _companyNameController.text = profile.name;
    _companyAddressController.text = profile.address;
    _companyPhoneController.text = profile.phone;
    _logoPath = profile.logoPath;
    _signaturePath = profile.signaturePath;
    if (mounted) setState(() {});
  }

  Future<void> _saveCompanySettings() async {
    if (_savingCompany) return;
    setState(() => _savingCompany = true);
    try {
      await ref.read(saveCompanyProfileProvider)(
        CompanyProfile(
          name: _companyNameController.text.trim(),
          address: _companyAddressController.text.trim(),
          phone: _companyPhoneController.text.trim(),
          logoPath: _logoPath,
          signaturePath: _signaturePath,
        ),
      );

      ref.invalidate(companyNameProvider);
      ref.invalidate(companyAddressProvider);
      ref.invalidate(companyPhoneProvider);
      ref.invalidate(companyLogoProvider);
      ref.invalidate(companySignatureProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText(AppStrings.successSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(context.trError(e))),
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
        _licenseInfo = context.trError(e);
        _loadingLicense = false;
      });
    }
  }

  Future<void> _saveLicense() async {
    final key = _licenseKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            AppCopy.licenceKeyIsRequired853b1e,
          ),
        ),
      );
      return;
    }
    try {
      await _licenseManager.saveLicense(key);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText(AppStrings.successSaved)),
      );
      await _loadLicenseInfo();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            context.trError(e),
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
        title: AppCopy.inactiveLicence,
        message: _licenseInfo ?? 'Aucune licence valide sur cet appareil.',
      );
    }

    final data = _licenseData;
    final expiry = data?.expiryDate;
    final daysLeft = expiry?.difference(DateTime.now()).inDays;
    // Warn while there is still time to obtain a new key.
    final expiringSoon = daysLeft != null && daysLeft <= 30;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DetailList(children: [
        DetailRow(
          icon: Icons.verified_user_outlined,
          label: AppCopy.statusd3b28a,
          value: expiringSoon ? AppCopy.expiresSoon : AppCopy.activeLicence,
          trailing: StatusChip(
            label: expiringSoon
                ? context.messages.remainingDayCount((daysLeft).toString())
                : AppCopy.valid,
            tone: expiringSoon ? AppTone.warning : AppTone.success,
            icon: expiringSoon ? Icons.warning_amber_rounded : Icons.check,
            dense: true,
          ),
        ),
        if (data != null && data.name.isNotEmpty)
          DetailRow(
              icon: Icons.business_outlined,
              label: AppCopy.licensedTo,
              value: data.name),
        if (data != null && data.features.isNotEmpty)
          DetailRow(
            icon: Icons.stars_outlined,
            label: AppCopy.includedFeatures,
            value: (data.features.toList()..sort())
                .map((key) => context.tr(licenseFeatureLabel(key)))
                .join(', '),
          ),
        if (expiry != null)
          DetailRow(
              icon: Icons.event_outlined,
              label: AppCopy.expiresOn,
              value: formatDate(expiry)),
        if (_deviceId != null)
          DetailRow(
            icon: Icons.smartphone_outlined,
            label: AppCopy.thisDeviceID,
            value: _deviceId!,
            mono: true,
            trailing: const Icon(Icons.copy_outlined,
                size: 18, color: AppColors.textSecondary),
            onTap: () {
              Clipboard.setData(ClipboardData(text: _deviceId!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: AppText(AppCopy.deviceIDCopied)),
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
              AppText(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _pickImage(isLogo),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.upload_file, size: 20),
                label: AppText(file == null ? AppCopy.add : AppCopy.change),
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
      title: AppText(title),
      subtitle: AppText(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  // A bare DropdownButton was the one control on this page that didn't open
  // the same full-width picker dialog as lead time, quiet hours and auto-lock
  // — smaller tap target, and visually a different kind of control.
  Future<void> _pickLanguage(AppLanguage current) async {
    final picked = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const AppText(AppCopy.language),
        children: [
          RadioGroup<AppLanguage>(
            groupValue: current,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    value: option,
                    title: AppText(option.label),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    await ref.read(appLanguageProvider.notifier).select(picked);
  }

  Widget _buildLanguageSettings(AppLanguage language) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _navRow(
        Icons.language_outlined,
        AppCopy.language,
        language.label,
        () => _pickLanguage(language),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = ref.watch(appLanguageProvider);
    final companyName = _companyNameController.text.trim();
    final notificationsOk = _notificationStatus?.isFullyGranted ?? true;

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
                          ? AppCopy.activeLicence
                          : AppCopy.inactiveLicence,
                  tone: _licenseValid ? AppTone.success : AppTone.danger,
                  icon: _licenseValid
                      ? Icons.verified_user_outlined
                      : Icons.error_outline,
                ),
                StatusChip(
                  label: notificationsOk
                      ? AppCopy.remindersActive
                      : AppCopy.remindersNeedAttention,
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
        AppCopy.myAgency,
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(Icons.business_outlined),
                  title: const AppText(AppCopy.companyInformation),
                  subtitle: const AppText(
                      AppCopy.nameAddressLogoAndSignatureOnContracts),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    TextField(
                      controller: _companyNameController,
                      decoration: InputDecoration(
                          labelText: context.tr(AppCopy.companyName)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _companyAddressController,
                      decoration: InputDecoration(
                          labelText: context.tr(AppCopy.address)),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _companyPhoneController,
                      decoration:
                          InputDecoration(labelText: context.tr(AppCopy.phone)),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildImagePicker(AppCopy.companyLogo, _logoPath, true),
                    const SizedBox(height: 12),
                    _buildImagePicker(
                        AppCopy.agencySignature, _signaturePath, false),
                    const SizedBox(height: 16),
                    AppButton(
                      label: AppCopy.save,
                      icon: Icons.save_outlined,
                      isLoading: _savingCompany,
                      onPressed: _saveCompanySettings,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _navRow(
                  Icons.badge_outlined,
                  AppCopy.drivers,
                  AppCopy.manageDriversTheirHourlyRateAndAvailability,
                  () => context.push('/chauffeurs')),
              const Divider(height: 1),
              _navRow(
                  Icons.auto_awesome_outlined,
                  AppCopy.localAssistant,
                  AppCopy.askAboutYourAgencyOfflineTheModelStays,
                  () => context.push('/assistant')),
            ],
          ),
        ),
      ),
      // Right after the agency's own identity: who can get in, and the one
      // button that locks it again. Previously this sat at the very bottom,
      // separated from "Verrouiller maintenant" by backup and licence — two
      // sections that have nothing to do with access.
      _group(
        AppCopy.security,
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              _navRow(
                  Icons.pin_outlined,
                  AppCopy.changePIN,
                  AppCopy.requiresTheCurrentPINBeforeAnyChange,
                  () => context.push('/settings/pin')),
              const Divider(height: 1),
              _navRow(
                  Icons.vpn_key_outlined,
                  AppCopy.recoveryCode,
                  AppCopy.generateANewCodeTheOldOneWill,
                  _regenerateRecoveryCode),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const AppText(AppCopy.biometricUnlock),
                subtitle: AppText(
                  _biometricAvailable
                      ? AppCopy.useFingerprintOrFaceRecognitionInsteadOfThe
                      : AppCopy.noFingerprintIsRegisteredOnThisDevice,
                ),
                value: _biometricEnabled && _biometricAvailable,
                onChanged: _biometricAvailable ? _setBiometric : null,
              ),
              const Divider(height: 1),
              _navRow(Icons.timer_outlined, AppCopy.automaticLock,
                  _autoLockLabel(_autoLockMinutes), _pickAutoLockDelay),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: OutlinedButton.icon(
          onPressed: () => ref.read(authProvider.notifier).lock(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTone.danger.color,
            side: BorderSide(color: AppTone.danger.color),
          ),
          icon: const Icon(Icons.lock_outline),
          label: const AppText(AppCopy.lockNow),
        ),
      ),
      _group(
        AppCopy.reminders,
        _buildNotificationSettings(theme),
        subtitle: AppCopy.returnsPaymentsAndLicence,
      ),
      _group(
        AppCopy.language,
        _buildLanguageSettings(language),
        subtitle: AppCopy.chooseTheApplicationLanguage,
      ),
      _group(
        AppCopy.backup,
        _buildBackupSettings(),
        subtitle: AppCopy.protectYourDataIfThePhoneIsLost,
      ),
      _group(
        AppCopy.licence,
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
                  title: const AppText(AppCopy.renewLicence),
                  subtitle:
                      const AppText(AppCopy.onlyToRenewOrAfterChangingDevices),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    TextField(
                      controller: _licenseKeyController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.tr(AppCopy.newLicenceKey),
                        hintText: context
                            .tr(AppCopy.pasteTheKeySuppliedByYourProviderHere),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: AppCopy.applyNewKey,
                      icon: Icons.vpn_key,
                      onPressed: _saveLicense,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    return AppPage.hero(
      title: AppCopy.settings,
      eyebrow: AppCopy.yourAgency,
      subtitle: companyName.isEmpty ? null : companyName,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/dashboard'),
        tooltip: context.tr(AppCopy.backToDashboard),
      ),
      children: items,
    );
  }
}
