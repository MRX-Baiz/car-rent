import '../repositories/reminder_source_repository.dart';
import '../services/reminder_scheduler.dart';

/// Re-creates a vehicle's maintenance reminders after it is saved. Mileage
/// reminders are evaluated at that same moment, because the odometer is only
/// updated by the agency, never automatically.
class SyncVehicleMaintenanceReminders {
  const SyncVehicleMaintenanceReminders(this._source, this._scheduler);

  final ReminderSourceRepository _source;
  final ReminderScheduler _scheduler;

  Future<void> call(int vehicleId, {bool requestPermissions = true}) async {
    final plan = await _source.vehiclePlan(vehicleId);
    if (plan == null) return;
    await _scheduler.scheduleVehicleMaintenanceReminders(
      plan,
      requestPermissions: requestPermissions,
    );
  }
}
