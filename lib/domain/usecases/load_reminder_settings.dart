import '../entities/reminder_settings.dart';
import '../repositories/reminder_preferences_repository.dart';
import '../services/reminder_scheduler.dart';

class LoadReminderSettings {
  const LoadReminderSettings(this._preferences, this._scheduler);

  final ReminderPreferencesRepository _preferences;
  final ReminderScheduler _scheduler;

  Future<ReminderSettings> call() async => ReminderSettings(
        preferences: await _preferences.load(),
        status: await _scheduler.diagnostics(),
      );
}
