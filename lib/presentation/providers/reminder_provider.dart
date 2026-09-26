import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_preferences.dart';
import '../../data/repositories/reminder_source_repository.dart';
import '../../data/services/notification_reminder_scheduler.dart';
import '../../domain/repositories/reminder_preferences_repository.dart';
import '../../domain/repositories/reminder_source_repository.dart';
import '../../domain/services/reminder_scheduler.dart';
import '../../domain/usecases/change_reminder_preferences.dart';
import '../../domain/usecases/load_reminder_settings.dart';
import '../../domain/usecases/request_reminder_permissions.dart';
import '../../domain/usecases/restore_contract_reminders.dart';
import '../../domain/usecases/restore_reminders_on_launch.dart';
import '../../domain/usecases/sync_contract_reminders.dart';
import '../../domain/usecases/sync_vehicle_maintenance_reminders.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return NotificationReminderScheduler.instance;
});

final reminderSourceRepositoryProvider =
    Provider<ReminderSourceRepository>((ref) {
  return SqliteReminderSourceRepository.instance;
});

final reminderPreferencesRepositoryProvider =
    Provider<ReminderPreferencesRepository>((ref) {
  return NotificationPreferencesRepository.instance;
});

final syncContractRemindersProvider = Provider<SyncContractReminders>((ref) {
  return SyncContractReminders(
    ref.watch(reminderSourceRepositoryProvider),
    ref.watch(reminderSchedulerProvider),
  );
});

final restoreContractRemindersProvider =
    Provider<RestoreContractReminders>((ref) {
  return RestoreContractReminders(
    ref.watch(reminderSourceRepositoryProvider),
    ref.watch(reminderSchedulerProvider),
  );
});

final syncVehicleMaintenanceRemindersProvider =
    Provider<SyncVehicleMaintenanceReminders>((ref) {
  return SyncVehicleMaintenanceReminders(
    ref.watch(reminderSourceRepositoryProvider),
    ref.watch(reminderSchedulerProvider),
  );
});

final restoreRemindersOnLaunchProvider =
    Provider<RestoreRemindersOnLaunch>((ref) {
  return RestoreRemindersOnLaunch(
    ref.watch(reminderSourceRepositoryProvider),
    ref.watch(reminderSchedulerProvider),
  );
});

final loadReminderSettingsProvider = Provider<LoadReminderSettings>((ref) {
  return LoadReminderSettings(
    ref.watch(reminderPreferencesRepositoryProvider),
    ref.watch(reminderSchedulerProvider),
  );
});

final requestReminderPermissionsProvider =
    Provider<RequestReminderPermissions>((ref) {
  return RequestReminderPermissions(
    ref.watch(reminderSchedulerProvider),
    ref.watch(loadReminderSettingsProvider),
  );
});

final changeReminderPreferencesProvider =
    Provider<ChangeReminderPreferences>((ref) {
  return ChangeReminderPreferences(
    ref.watch(reminderPreferencesRepositoryProvider),
    ref.watch(reminderSchedulerProvider),
    ref.watch(restoreContractRemindersProvider),
  );
});
