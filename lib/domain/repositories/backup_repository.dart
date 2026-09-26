/// A finished backup archive, addressed by path so the domain stays free of
/// `dart:io`.
class BackupArchive {
  const BackupArchive(this.path);

  final String path;
}

/// Portable backup of the agency's data and attachments.
abstract interface class BackupRepository {
  Future<BackupArchive> create();

  /// Replaces the business data with the archive at [archivePath].
  ///
  /// [beforeReplace] runs only after the archive has passed validation, so a
  /// bad file never disturbs anything that was working.
  Future<void> restore(
    String archivePath, {
    Future<void> Function()? beforeReplace,
  });
}
