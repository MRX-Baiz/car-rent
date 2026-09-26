import '../entities/reminder_plans.dart';
import '../repositories/reminder_source_repository.dart';
import '../services/reminder_scheduler.dart';

/// Brings one contract's reminders in line with what is stored.
///
/// Run after every change to a contract — created, edited, closed or deleted —
/// so no caller can leave reminders behind. That is how a deleted contract once
/// kept nagging about a vehicle that no longer existed.
class SyncContractReminders {
  const SyncContractReminders(this._source, this._scheduler);

  final ReminderSourceRepository _source;
  final ReminderScheduler _scheduler;

  Future<void> call(int contractId, {bool requestPermissions = true}) async {
    final plan = await _source.contractPlan(contractId);
    await applyContractReminderPlan(
      _scheduler,
      contractId,
      plan,
      requestPermissions: requestPermissions,
    );
  }
}

/// A contract that is gone, or no longer active, has no reminders.
Future<void> applyContractReminderPlan(
  ReminderScheduler scheduler,
  int contractId,
  ContractReminderPlan? plan, {
  required bool requestPermissions,
}) {
  if (plan == null || !plan.isActive) {
    return scheduler.cancelContractReminders(contractId);
  }
  return scheduler.scheduleContractReminders(
    plan,
    requestPermissions: requestPermissions,
  );
}
