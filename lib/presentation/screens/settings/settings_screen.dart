import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/license/license_manager.dart';
import '../../../core/notifications/notification_preferences.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../data/models/license_model.dart';
import '../../../core/storage/media_store.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/contract_provider.dart';
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

  String _logoPath = '';
  String _signaturePath = '';
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  int _autoLockMinutes = AuthRepository.defaultAutoLockMinutes;

  NotificationPreferences _notifications = const NotificationPreferences();
  bool _notificationsGranted = false;

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
    final granted = await NotificationService.instance.hasPermission();
    if (!mounted) return;
    setState(() {
      _notifications = preferences;
      _notificationsGranted = granted;
    });
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
    final current = isStart
        ? _notifications.quietStartHour
        : _notifications.quietEndHour;
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

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Rappels de retour'),
            subtitle: Text(
              enabled && !_notificationsGranted
                  ? 'Bloqués par Android — activez-les dans les réglages système.'
                  : 'Retours prévus, véhicules en retard, paiements.',
              style: enabled && !_notificationsGranted
                  ? TextStyle(color: theme.colorScheme.error)
                  : null,
            ),
            value: enabled,
            onChanged: (value) =>
                _updateNotifications(_notifications.copyWith(enabled: value)),
          ),
          if (enabled) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Prévenir avant l\'échéance'),
              subtitle: Text(_leadLabel(_notifications.leadMinutes)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickLeadTime,
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.payments_outlined),
              title: const Text('Rappels de paiement'),
              subtitle: const Text('Quand un solde reste dû à l\'échéance.'),
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
                    ? 'Reporté à ${_formatHour(_notifications.quietEndHour)}'
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
                      subtitle:
                          Text(_formatHour(_notifications.quietStartHour)),
                      onTap: () => _pickQuietHour(isStart: true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('À'),
                      subtitle: Text(_formatHour(_notifications.quietEndHour)),
                      onTap: () => _pickQuietHour(isStart: false),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
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
                  ? const Text('Redemande le code après chaque scan de document.')
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

  @override
  void dispose() {
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
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _licenseInfo ?? 'Licence inactive.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      );
    }

    final data = _licenseData;
    final expiry = data?.expiryDate;
    final daysLeft =
        expiry == null ? null : expiry.difference(DateTime.now()).inDays;
    // Warn while there is still time to obtain a new key.
    final expiringSoon = daysLeft != null && daysLeft <= 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              expiringSoon ? Icons.warning_amber_rounded : Icons.verified_user,
              color: expiringSoon ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              'Licence active',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (data != null && data.name.isNotEmpty)
          Text('Licencié à : ${data.name}'),
        if (expiry != null) ...[
          const SizedBox(height: 2),
          Text(
            'Expire le : ${DateFormat('dd/MM/yyyy').format(expiry)}'
            '${daysLeft != null ? '  ($daysLeft jours restants)' : ''}',
            style: expiringSoon
                ? const TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold)
                : null,
          ),
        ],
        if (_deviceId != null) ...[
          const SizedBox(height: 8),
          Text(
            'ID de cet appareil',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _deviceId!,
                  style: const TextStyle(
                      fontFamily: 'Courier', fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copier l\'ID',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _deviceId!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('ID de l\'appareil copié !')),
                  );
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImagePicker(String label, String path, bool isLogo) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child: MediaStore.instance.resolveFile(path) != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    MediaStore.instance.resolveFile(path)!,
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(Icons.image, color: Colors.grey),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                path.isEmpty ? 'Aucune image' : path.split('/').last,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickImage(isLogo),
                icon: const Icon(Icons.upload_file),
                label: const Text('Sélectionner'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
          tooltip: 'Retour au tableau de bord',
        ),
        title: const Text('Paramètres'),
      ),
      body: SingleChildScrollView(
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
                Text(
                  'Informations de la société',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la société',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _companyAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _companyPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 16),
                _buildImagePicker('Logo de la société', _logoPath, true),
                const SizedBox(height: 16),
                _buildImagePicker('Signature de l\'agence', _signaturePath, false),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _savingCompany ? null : _saveCompanySettings,
                  icon: _savingCompany
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Enregistrer les informations'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Licence',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_loadingLicense)
                  const LinearProgressIndicator()
                else
                  _buildLicenseStatus(theme),
                const SizedBox(height: 16),

                // Spelling out when this is needed; without it the field looks
                // redundant while a licence is already active.
                Text(
                  'Renouvellement',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'À utiliser uniquement pour prolonger la licence avant son '
                  'expiration, ou après un changement d\'appareil. '
                  'Aucune action n\'est requise tant que la licence est valide.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _licenseKeyController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Nouvelle clé de licence',
                    hintText: 'Collez ici la clé fournie par votre fournisseur',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _saveLicense,
                  icon: const Icon(Icons.vpn_key),
                  label: const Text('Appliquer la nouvelle clé'),
                ),


                const SizedBox(height: 32),
                Text(
                  'Rappels',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildNotificationSettings(theme),

                const SizedBox(height: 32),
                Text(
                  'Session et Sécurité',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.pin_outlined),
                        title: const Text('Modifier le code PIN'),
                        subtitle: const Text(
                          'Demande le code actuel avant tout changement.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/settings/pin'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.vpn_key_outlined),
                        title: const Text('Code de récupération'),
                        subtitle: const Text(
                          'Générer un nouveau code. L\'ancien sera annulé.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _regenerateRecoveryCode,
                      ),
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
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Verrouillage automatique'),
                        subtitle: Text(_autoLockLabel(_autoLockMinutes)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickAutoLockDelay,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_outline, color: Colors.red),
                        title: const Text(
                          'Verrouiller maintenant',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () => ref.read(authProvider.notifier).lock(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
