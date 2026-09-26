import '../repositories/reminder_source_repository.dart';
import '../services/reminder_scheduler.dart';
import 'sync_contract_reminders.dart';

/// Re-arms every reminder when the app opens: Android drops pending alarms on
/// force-stop, and the licence expiry moves whenever a new key is applied.
///
/// No overdue alert is raised here — the operator is about to see the
/// dashboard — so a summary left over from last time is cleared instead.
class RestoreRemindersOnLaunch {
  const RestoreRemindersOnLaunch(this._source, this._scheduler);

  final ReminderSourceRepository _source;
  final ReminderScheduler _scheduler;

  Future<void> call({DateTime? licenseExpiry}) async {
    for (final plan in await _source.allContractPlans()) {
      await applyContractReminderPlan(
        _scheduler,
        plan.contractId,
        plan,
        requestPermissions: false,
      );
    }
    for (final plan in await _source.allVehiclePlans()) {
      await _scheduler.scheduleVehicleMaintenanceReminders(
        plan,
        requestPermissions: false,
      );
    }
    if (licenseExpiry != null) {
      await _scheduler.scheduleLicenseExpiry(licenseExpiry);
    }
    await _scheduler.dismissLateDigest();
  }
}
