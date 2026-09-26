import '../entities/notification_preferences.dart';

abstract interface class ReminderPreferencesRepository {
  Future<NotificationPreferences> load();

  Future<void> save(NotificationPreferences preferences);
}
