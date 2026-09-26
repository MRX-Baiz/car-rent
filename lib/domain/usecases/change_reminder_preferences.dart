import '../entities/notification_preferences.dart';
import '../entities/reminder_settings.dart';
import '../repositories/reminder_preferences_repository.dart';
import '../services/reminder_scheduler.dart';
import 'restore_contract_reminders.dart';

/// Applies new reminder preferences.
///
/// Turning reminders on is worthless if the OS is dropping them, so the
/// permission is asked for at the moment the operator shows they want them —
/// and a refusal leaves the previous choice untouched. Turning them off
/// silences what is already scheduled, not just what would be added later.
class ChangeReminderPreferences {
  const ChangeReminderPreferences(
    this._preferences,
    this._scheduler,
    this._restoreContractReminders,
  );

  final ReminderPreferencesRepository _preferences;
  final ReminderScheduler _scheduler;
  final RestoreContractReminders _restoreContractReminders;

  Future<ReminderPreferencesResult> call(
    NotificationPreferences updated, {
    required bool permissionGranted,
  }) async {
    var granted = permissionGranted;
    if (updated.enabled && !granted) {
      granted = await _scheduler.requestPermission();
      if (!granted) {
        return const ReminderPreferencesResult(
          saved: false,
          permissionGranted: false,
        );
      }
    }

    await _preferences.save(updated);
    if (updated.enabled) {
      // New lead times and quiet hours apply to alarms that already exist.
      await _restoreContractReminders(requestPermissions: true);
    } else {
      await _scheduler.cancelAll();
    }
    return ReminderPreferencesResult(saved: true, permissionGranted: granted);
  }
}
