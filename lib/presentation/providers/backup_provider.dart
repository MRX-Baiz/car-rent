import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/backup_repository.dart';
import '../../domain/repositories/backup_repository.dart';
import '../../domain/usecases/create_backup.dart';
import '../../domain/usecases/restore_backup.dart';
import 'reminder_provider.dart';

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return ZipBackupRepository.instance;
});

final createBackupProvider = Provider<CreateBackup>((ref) {
  return CreateBackup(ref.watch(backupRepositoryProvider));
});

final restoreBackupProvider = Provider<RestoreBackup>((ref) {
  return RestoreBackup(
    ref.watch(backupRepositoryProvider),
    ref.watch(reminderSchedulerProvider),
    ref.watch(restoreContractRemindersProvider),
  );
});
