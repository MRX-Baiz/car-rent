import 'notification_diagnostics.dart';
import 'notification_preferences.dart';

/// What the reminder settings screen shows: the operator's choices, and
/// whether the OS will actually honour them.
class ReminderSettings {
  const ReminderSettings({required this.preferences, required this.status});

  final NotificationPreferences preferences;
  final NotificationDiagnostics status;
}

/// Outcome of changing the reminder preferences.
class ReminderPreferencesResult {
  const ReminderPreferencesResult({
    required this.saved,
    required this.permissionGranted,
  });

  /// False when the change was refused because the OS denied the permission
  /// that turning reminders on depends on.
  final bool saved;
  final bool permissionGranted;
}
