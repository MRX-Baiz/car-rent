import '../repositories/backup_repository.dart';

class CreateBackup {
  const CreateBackup(this._repository);

  final BackupRepository _repository;

  Future<BackupArchive> call() => _repository.create();
}
