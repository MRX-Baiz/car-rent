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

  /// Lead times offered in settings, in minutes.
  static const List<int> leadChoices = <int>[15, 30, 60, 120, 1440];

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
