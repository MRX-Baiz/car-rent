import '../repositories/backup_repository.dart';
import '../services/reminder_scheduler.dart';
import 'restore_contract_reminders.dart';

/// Replaces the agency's data with a backup and keeps reminders honest.
///
/// Pending alarms belong to the old database, so they are cleared — but only
/// once the archive has passed validation, because a bad file must not silence
/// reminders that were working. Reminders for the restored active contracts are
/// then created again.
class RestoreBackup {
  const RestoreBackup(
    this._repository,
    this._scheduler,
    this._restoreContractReminders,
  );

  final BackupRepository _repository;
  final ReminderScheduler _scheduler;
  final RestoreContractReminders _restoreContractReminders;

  Future<void> call(String archivePath) async {
    await _repository.restore(
      archivePath,
      beforeReplace: _scheduler.cancelAll,
    );
    await _restoreContractReminders();
  }
}
