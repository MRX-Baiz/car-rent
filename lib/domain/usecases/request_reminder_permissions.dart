import '../entities/reminder_settings.dart';
import '../services/reminder_scheduler.dart';
import 'load_reminder_settings.dart';

/// Asks the OS for the permissions reminders depend on, then reports where
/// that leaves them — the operator may have granted only part of it.
class RequestReminderPermissions {
  const RequestReminderPermissions(this._scheduler, this._load);

  final ReminderScheduler _scheduler;
  final LoadReminderSettings _load;

  Future<ReminderSettings> call() async {
    await _scheduler.requestPermission();
    return _load();
  }
}
