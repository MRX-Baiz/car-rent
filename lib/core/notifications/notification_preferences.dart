import '../../data/repositories/app_settings_repository.dart';
import '../../data/repositories/key_value_store.dart';

/// What the user has chosen about reminders.
class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.leadMinutes = 60,
    this.paymentReminders = true,
    this.licenseAlerts = true,
    this.quietHoursEnabled = false,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
  });

  /// Master switch. Off means nothing is scheduled and nothing is shown.
  final bool enabled;

  /// How long before a return deadline the first reminder fires.
  final int leadMinutes;

  final bool paymentReminders;
  final bool licenseAlerts;

  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietEndHour;

  /// True when [hour] falls inside the quiet window, which may wrap midnight.
  bool isQuiet(int hour) {
    if (!quietHoursEnabled || quietStartHour == quietEndHour) {
      return false;
    }
    if (quietStartHour < quietEndHour) {
      return hour >= quietStartHour && hour < quietEndHour;
    }
    // Wraps midnight, e.g. 22:00 to 07:00.
    return hour >= quietStartHour || hour < quietEndHour;
  }

  NotificationPreferences copyWith({
    bool? enabled,
    int? leadMinutes,
    bool? paymentReminders,
    bool? licenseAlerts,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      leadMinutes: leadMinutes ?? this.leadMinutes,
      paymentReminders: paymentReminders ?? this.paymentReminders,
      licenseAlerts: licenseAlerts ?? this.licenseAlerts,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
    );
  }
}

class NotificationPreferencesRepository {
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

  /// Lead times offered in settings, in minutes.
  static const List<int> leadChoices = <int>[15, 30, 60, 120, 1440];

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
