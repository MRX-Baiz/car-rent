import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../storage/media_store.dart';
import '../../data/repositories/auth_repository.dart';

/// Creates and restores portable CarRent backup archives.
///
/// A backup has the SQLite database and every saved attachment. Licences are
/// deliberately not included: they are tied to one Android device. PIN and
/// recovery secrets are excluded too; when restoring on this phone, the
/// current phone's PIN is preserved.
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const _format = 'carrent-backup';
  static const _version = 1;
  static const _databaseEntry = 'database.sqlite';
  static const _manifestEntry = 'manifest.json';
  static const _mediaPrefix = 'media/';

  static const _securityKeys = <String>[
    AuthRepository.keyPinSalt,
    AuthRepository.keyPinHash,
    AuthRepository.keyPinIterations,
    AuthRepository.keyRecoverySalt,
    AuthRepository.keyRecoveryHash,
    AuthRepository.keyRecoveryIterations,
    AuthRepository.keyResetSerial,
    AuthRepository.keyFailedAttempts,
    AuthRepository.keyLockedUntil,
    AuthRepository.keyBiometricEnabled,
    AuthRepository.keyAutoLockMinutes,
  ];

  /// Creates a ZIP file. [outputDirectory] is useful for tests; the app uses
  /// its documents directory by default.
  Future<File> createBackup({
    Directory? outputDirectory,
    Directory? workingDirectory,
  }) async {
    final work = workingDirectory ?? await getTemporaryDirectory();
    final staging = await work.createTemp('carrent_backup_');
    try {
      await DatabaseHelper.instance.close();
      final databaseFile = await DatabaseHelper.instance.databaseFile;
      if (!await databaseFile.exists()) {
        throw StateError('Aucune donnée à sauvegarder.');
      }

      final copiedDatabase = File(p.join(staging.path, _databaseEntry));
      await databaseFile.copy(copiedDatabase.path);
      await _removeDeviceSecrets(copiedDatabase);

      final archive = Archive();
      final databaseBytes = await copiedDatabase.readAsBytes();
      archive.addFile(
        ArchiveFile(_databaseEntry, databaseBytes.length, databaseBytes),
      );

      var mediaCount = 0;
      final mediaDirectory = MediaStore.instance.directory;
      if (await mediaDirectory.exists()) {
        await for (final entity in mediaDirectory.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          final bytes = await entity.readAsBytes();
          archive
              .addFile(ArchiveFile('$_mediaPrefix$name', bytes.length, bytes));
          mediaCount++;
        }
      }

      final manifest = <String, Object>{
        'format': _format,
        'version': _version,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'mediaCount': mediaCount,
      };
      final manifestBytes = utf8.encode(jsonEncode(manifest));
      archive.addFile(
        ArchiveFile(_manifestEntry, manifestBytes.length, manifestBytes),
      );

      final bytes = ZipEncoder().encode(archive);
      if (bytes == null) {
        throw StateError('Impossible de créer le fichier ZIP.');
      }

      final destination = outputDirectory ??
          Directory(p.join(
              (await getApplicationDocumentsDirectory()).path, 'backups'));
      await destination.create(recursive: true);
      final timestamp = _fileTimestamp(DateTime.now());
      final output = File(p.join(destination.path, 'CarRent_$timestamp.zip'));
      await output.writeAsBytes(bytes, flush: true);
      return output;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Replaces the business data and attachments with [archiveFile].
  ///
  /// Existing device security settings remain on this phone. Callers should
  /// cancel current notifications and re-arm reminders after this operation.
  Future<void> restoreBackup(
    File archiveFile, {
    Directory? workingDirectory,
    Future<void> Function()? beforeReplace,
  }) async {
    if (!await archiveFile.exists()) {
      throw const BackupFormatException('Fichier de sauvegarde introuvable.');
    }

    final archive = _readArchive(await archiveFile.readAsBytes());
    final work = workingDirectory ?? await getTemporaryDirectory();
    final staging = await work.createTemp('carrent_restore_');
    try {
      final stagedDatabase = await _extractAndValidate(archive, staging);
      final security = await _readCurrentSecuritySettings();

      // The UI clears Android alarms here only after the ZIP and database have
      // both passed validation. A bad file must not silence valid reminders.
      await beforeReplace?.call();
      await DatabaseHelper.instance.close();
      final liveDatabase = await DatabaseHelper.instance.databaseFile;
      await _replaceFile(stagedDatabase, liveDatabase);
      await _restoreCurrentSecuritySettings(security);
      await _replaceMedia(archive, staging);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Archive _readArchive(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final manifestFile = archive.findFile(_manifestEntry);
      if (manifestFile == null || !manifestFile.isFile) {
        throw const BackupFormatException(
            'Ce fichier n\'est pas une sauvegarde CarRent.');
      }
      final manifest =
          jsonDecode(utf8.decode(manifestFile.content as List<int>));
      if (manifest is! Map ||
          manifest['format'] != _format ||
          manifest['version'] != _version ||
          archive.findFile(_databaseEntry) == null) {
        throw const BackupFormatException(
            'Format de sauvegarde non pris en charge.');
      }
      return archive;
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException(
          'Le fichier ZIP est invalide ou endommagé.');
    }
  }

  Future<File> _extractAndValidate(Archive archive, Directory staging) async {
    final database = archive.findFile(_databaseEntry)!;
    if (!database.isFile || database.isSymbolicLink || database.size <= 0) {
      throw const BackupFormatException(
          'Base de données de sauvegarde invalide.');
    }
    final stagedDatabase = File(p.join(staging.path, _databaseEntry));
    await stagedDatabase.writeAsBytes(database.content as List<int>,
        flush: true);

    // Check every document name before replacing any live data. ZIP paths are
    // untrusted input, so an archive can only hold flat files under media/.
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith(_mediaPrefix)) continue;
      final name = file.name.substring(_mediaPrefix.length);
      if (!_safeMediaName(name) || file.isSymbolicLink) {
        throw const BackupFormatException(
          'Nom de document invalide dans la sauvegarde.',
        );
      }
    }

    Database? db;
    try {
      db = await openDatabase(stagedDatabase.path, readOnly: true);
      const required = <String>{
        'vehicles',
        'clients',
        'contracts',
        'payments',
        'app_settings',
      };
      final rows = await db.query('sqlite_master',
          columns: const ['name'], where: "type = 'table'");
      final tables = rows.map((row) => row['name']).toSet();
      if (!tables.containsAll(required)) {
        throw const BackupFormatException(
            'Cette sauvegarde ne contient pas les données CarRent.');
      }
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException(
          'Base de données de sauvegarde invalide.');
    } finally {
      await db?.close();
    }
    return stagedDatabase;
  }

  Future<Map<String, String>> _readCurrentSecuritySettings() async {
    final db = await DatabaseHelper.instance.database;
    final placeholders =
        List<String>.filled(_securityKeys.length, '?').join(', ');
    final rows = await db.query(
      'app_settings',
      columns: const ['key', 'value'],
      where: 'key IN ($placeholders)',
      whereArgs: _securityKeys,
    );
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> _restoreCurrentSecuritySettings(
      Map<String, String> values) async {
    if (values.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (final entry in values.entries) {
      batch.insert(
        'app_settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _removeDeviceSecrets(File databaseFile) async {
    final db = await openDatabase(databaseFile.path);
    try {
      final placeholders =
          List<String>.filled(_securityKeys.length, '?').join(', ');
      await db.delete(
        'app_settings',
        where: 'key IN ($placeholders)',
        whereArgs: _securityKeys,
      );
      await db.delete('license_data');
    } finally {
      await db.close();
    }
  }

  Future<void> _replaceFile(File source, File destination) async {
    final replacement = File('${destination.path}.restore');
    if (await replacement.exists()) await replacement.delete();
    await source.copy(replacement.path);
    if (await destination.exists()) await destination.delete();
    await replacement.rename(destination.path);
  }

  Future<void> _replaceMedia(Archive archive, Directory staging) async {
    final mediaDirectory = MediaStore.instance.directory;
    await mediaDirectory.create(recursive: true);
    final stagedMedia = Directory(p.join(staging.path, 'media'));
    await stagedMedia.create(recursive: true);

    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith(_mediaPrefix)) continue;
      final name = file.name.substring(_mediaPrefix.length);
      if (!_safeMediaName(name) || file.isSymbolicLink) {
        throw const BackupFormatException(
            'Nom de document invalide dans la sauvegarde.');
      }
      await File(p.join(stagedMedia.path, name))
          .writeAsBytes(file.content as List<int>, flush: true);
    }

    await for (final entity in mediaDirectory.list(followLinks: false)) {
      await entity.delete(recursive: true);
    }
    await for (final entity in stagedMedia.list(followLinks: false)) {
      if (entity is File) {
        await entity.copy(p.join(mediaDirectory.path, p.basename(entity.path)));
      }
    }
  }

  bool _safeMediaName(String name) =>
      name.isNotEmpty &&
      p.basename(name) == name &&
      !name.contains('..') &&
      !p.isAbsolute(name);

  static String _fileTimestamp(DateTime time) =>
      '${time.year}${time.month.toString().padLeft(2, '0')}${time.day.toString().padLeft(2, '0')}_'
      '${time.hour.toString().padLeft(2, '0')}${time.minute.toString().padLeft(2, '0')}${time.second.toString().padLeft(2, '0')}';
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}
