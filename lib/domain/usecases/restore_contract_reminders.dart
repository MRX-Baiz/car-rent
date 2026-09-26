import '../repositories/reminder_source_repository.dart';
import '../services/reminder_scheduler.dart';
import 'sync_contract_reminders.dart';

/// Replaces every contract's reminders using the current scheduling rules, and
/// clears those of contracts that are no longer active.
///
/// Silent by default: it runs at launch and after a restore, moments when the
/// operator should not be met with a permission prompt.
class RestoreContractReminders {
  const RestoreContractReminders(this._source, this._scheduler);

  final ReminderSourceRepository _source;
  final ReminderScheduler _scheduler;

  Future<void> call({bool requestPermissions = false}) async {
    for (final plan in await _source.allContractPlans()) {
      await applyContractReminderPlan(
        _scheduler,
        plan.contractId,
        plan,
        requestPermissions: requestPermissions,
      );
    }
  }
}
