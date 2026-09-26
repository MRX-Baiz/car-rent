import '../../data/repositories/app_settings_repository.dart';
import '../../data/repositories/key_value_store.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/reminder_preferences_repository.dart';

// The entity lives in the domain; re-exported so the notification code and its
// tests can keep importing it from here.
export '../../domain/entities/notification_preferences.dart';

class NotificationPreferencesRepository
    implements ReminderPreferencesRepository {
  NotificationPreferencesRepository({KeyValueStore? store})
      : _store = store ?? AppSettingsRepository.instance;

  static final NotificationPreferencesRepository instance =
      NotificationPreferencesRepository();

  final KeyValueStore _store;

  static const String keyEnabled = 'notif_enabled';
  static const String keyLeadMinutes = 'notif_lead_minutes';
  static const String keyPayments = 'notif_payments';
  static const String keyLicense = 'notif_license';
  static const String keyQuietEnabled = 'notif_quiet_enabled';
  static const String keyQuietStart = 'notif_quiet_start';
  static const String keyQuietEnd = 'notif_quiet_end';

  static const List<int> leadChoices = NotificationPreferences.leadChoices;

  @override
  Future<NotificationPreferences> load() async {
    const defaults = NotificationPreferences();
    return NotificationPreferences(
      enabled: await _bool(keyEnabled, defaults.enabled),
      leadMinutes: await _int(keyLeadMinutes, defaults.leadMinutes),
      paymentReminders: await _bool(keyPayments, defaults.paymentReminders),
      licenseAlerts: await _bool(keyLicense, defaults.licenseAlerts),
      quietHoursEnabled:
          await _bool(keyQuietEnabled, defaults.quietHoursEnabled),
      quietStartHour: await _int(keyQuietStart, defaults.quietStartHour),
      quietEndHour: await _int(keyQuietEnd, defaults.quietEndHour),
    );
  }

  @override
  Future<void> save(NotificationPreferences preferences) async {
    await _store.setString(keyEnabled, preferences.enabled.toString());
    await _store.setString(keyLeadMinutes, preferences.leadMinutes.toString());
    await _store.setString(
        keyPayments, preferences.paymentReminders.toString());
    await _store.setString(keyLicense, preferences.licenseAlerts.toString());
    await _store.setString(
        keyQuietEnabled, preferences.quietHoursEnabled.toString());
    await _store.setString(
        keyQuietStart, preferences.quietStartHour.toString());
    await _store.setString(keyQuietEnd, preferences.quietEndHour.toString());
  }

  Future<bool> _bool(String key, bool fallback) async {
    final raw = await _store.getString(key);
    if (raw.isEmpty) return fallback;
    return raw.toLowerCase() == 'true';
  }

  Future<int> _int(String key, int fallback) async {
    return int.tryParse(await _store.getString(key)) ?? fallback;
  }
}
