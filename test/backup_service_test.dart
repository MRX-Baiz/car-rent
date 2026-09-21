import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:car_rent_manager/core/backup/backup_service.dart';
import 'package:car_rent_manager/core/database/database_helper.dart';
import 'package:car_rent_manager/core/storage/media_store.dart';
import 'package:car_rent_manager/data/repositories/auth_repository.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  late Directory root;
  late Directory media;
  late File backup;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    root = await Directory.systemTemp.createTemp('carrent_backup_test_');
    media = Directory(p.join(root.path, 'media'));
    await media.create();
    MediaStore.instance.debugSetDirectory(media);
    await databaseFactory.setDatabasesPath(root.path);
    await DatabaseHelper.instance.close();

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('vehicles', {
      'brand': 'Renault',
      'model': 'Clio',
      'registration_number': '12345-A-6',
      'year': 2024,
      'status': 'available',
      'daily_price': 250.0,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(
      'app_settings',
      {'key': 'company_name', 'value': 'Atlas Rent'},
    );
    await db.insert('app_settings', {
      'key': AuthRepository.keyPinHash,
      'value': 'private-pin-hash',
    });
    await File(p.join(media.path, 'logo.png')).writeAsBytes(<int>[1, 2, 3]);

    backup = await BackupService.instance.createBackup(
      outputDirectory: Directory(p.join(root.path, 'backups')),
      workingDirectory: root,
    );
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('backup contains business data and media but excludes device secrets',
      () async {
    expect(await backup.exists(), isTrue);
    final archive = ZipDecoder().decodeBytes(await backup.readAsBytes());
    final manifest = jsonDecode(
      utf8.decode(archive.findFile('manifest.json')!.content as List<int>),
    ) as Map<String, dynamic>;
    expect(manifest['format'], 'carrent-backup');
    expect(manifest['version'], 1);
    expect(archive.findFile('media/logo.png'), isNotNull);

    final restoredDb = File(p.join(root.path, 'archive_check.sqlite'));
    await restoredDb.writeAsBytes(
      archive.findFile('database.sqlite')!.content as List<int>,
    );
    final archiveDb = await databaseFactory.openDatabase(restoredDb.path);
    expect(
      await archiveDb.query(
        'vehicles',
        where: 'brand = ?',
        whereArgs: ['Renault'],
      ),
      hasLength(1),
    );
    expect(
      await archiveDb.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [AuthRepository.keyPinHash],
      ),
      isEmpty,
    );
    await archiveDb.close();
  });

  test('restore replaces data and documents but keeps this phone PIN',
      () async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'vehicles',
      {'brand': 'Changed'},
      where: 'registration_number = ?',
      whereArgs: ['12345-A-6'],
    );
    await db.insert(
      'app_settings',
      {'key': AuthRepository.keyPinHash, 'value': 'current-phone-pin'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await File(p.join(media.path, 'old.jpg')).writeAsBytes(<int>[9]);

    await BackupService.instance.restoreBackup(backup, workingDirectory: root);

    final restored = await DatabaseHelper.instance.database;
    final vehicles = await restored.query('vehicles');
    expect(vehicles.single['brand'], 'Renault');
    final pin = await restored.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [AuthRepository.keyPinHash],
    );
    expect(pin.single['value'], 'current-phone-pin');
    expect(await File(p.join(media.path, 'logo.png')).exists(), isTrue);
    expect(await File(p.join(media.path, 'old.jpg')).exists(), isFalse);
  });

  test('invalid ZIP is rejected before it changes current data', () async {
    final invalid = File(p.join(root.path, 'invalid.zip'));
    await invalid.writeAsString('not a ZIP');
    var beforeReplaceCalled = false;

    expect(
      () => BackupService.instance.restoreBackup(
        invalid,
        workingDirectory: root,
        beforeReplace: () async {
          beforeReplaceCalled = true;
        },
      ),
      throwsA(isA<BackupFormatException>()),
    );

    expect(beforeReplaceCalled, isFalse);
    final db = await DatabaseHelper.instance.database;
    expect(await db.query('vehicles'), hasLength(1));
  });
}
