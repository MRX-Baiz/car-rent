import 'dart:io';

import '../../core/backup/backup_service.dart';
import '../../domain/repositories/backup_repository.dart';

/// Backs the agency up as one ZIP: the SQLite database plus every attachment.
class ZipBackupRepository implements BackupRepository {
  ZipBackupRepository._();

  static final instance = ZipBackupRepository._();

  @override
  Future<BackupArchive> create() async {
    final file = await BackupService.instance.createBackup();
    return BackupArchive(file.path);
  }

  @override
  Future<void> restore(
    String archivePath, {
    Future<void> Function()? beforeReplace,
  }) {
    return BackupService.instance.restoreBackup(
      File(archivePath),
      beforeReplace: beforeReplace,
    );
  }
}
