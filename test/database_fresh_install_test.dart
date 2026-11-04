import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:car_rent_manager/core/database/database_helper.dart';
import 'package:car_rent_manager/data/models/client_model.dart';

/// Guards against schema drift between [DatabaseHelper._onCreate] (fresh
/// install) and [DatabaseHelper._onUpgrade] (existing install migrated up).
/// A fresh install has no on-disk database, so only onCreate ever runs -
/// any column added exclusively via onUpgrade is invisible to new users.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;

  setUp(() async {
    final dir = await databaseFactory.getDatabasesPath();
    dbPath = p.join(dir, 'car_rent_manager.db');
    await databaseFactory.deleteDatabase(dbPath);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('fresh install can insert a client (no onUpgrade-only columns missing)',
      () async {
    // Forces DatabaseHelper._onCreate to run against a brand new file, exactly
    // like a customer's first launch on a clean machine.
    await DatabaseHelper.instance.database;

    final client = ClientModel(
      id: null,
      firstName: 'Hossam',
      lastName: 'Baiz',
      cin: 'D123456',
      licenseNumber: '12/345678',
      address: null,
      phone: '0600000000',
      email: null,
      cinImagePath: null,
      licenseImagePath: null,
      licenseExpiryDate: DateTime(2030, 1, 1),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final db = await DatabaseHelper.instance.database;
    // Exercises the exact insert path ClientRepository.insertClient uses.
    final id = await db.insert('clients', client.toMap()..remove('id'));

    expect(id, greaterThan(0));
  });

  test('fresh install rejects duplicate license_number (unique index present)',
      () async {
    await DatabaseHelper.instance.database;
    final db = await DatabaseHelper.instance.database;

    final now = DateTime.now().toIso8601String();
    await db.insert('clients', {
      'first_name': 'A',
      'last_name': 'B',
      'cin': 'D000001',
      'license_number': 'DUP/000001',
      'phone': '0600000001',
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
    });

    expect(
      () => db.insert('clients', {
        'first_name': 'C',
        'last_name': 'D',
        'cin': 'D000002',
        'license_number': 'DUP/000001',
        'phone': '0600000002',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      }),
      throwsA(isA<Exception>()),
    );
  });

  test('fresh install can insert a vehicle expense (vehicle_expenses exists)',
      () async {
    await DatabaseHelper.instance.database;
    final db = await DatabaseHelper.instance.database;

    final now = DateTime.now().toIso8601String();
    final vehicleId = await db.insert('vehicles', {
      'brand': 'Dacia',
      'model': 'Logan',
      'registration_number': '00000-A-1',
      'year': 2022,
      'status': 'available',
      'created_at': now,
      'updated_at': now,
    });

    final id = await db.insert('vehicle_expenses', {
      'vehicle_id': vehicleId,
      'category': 'repair',
      'amount': 250.0,
      'expense_date': now,
      'created_at': now,
    });

    expect(id, greaterThan(0));
  });

  test('fresh install defaults requires_manager_approval to 0 and can flip it',
      () async {
    await DatabaseHelper.instance.database;
    final db = await DatabaseHelper.instance.database;

    final now = DateTime.now().toIso8601String();
    final id = await db.insert('clients', {
      'first_name': 'A',
      'last_name': 'B',
      'cin': 'D000003',
      'license_number': 'APR/000001',
      'phone': '0600000003',
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
    });

    final inserted =
        await db.query('clients', where: 'id = ?', whereArgs: [id]);
    expect(inserted.single['requires_manager_approval'], 0);

    await db.update('clients', {'requires_manager_approval': 1},
        where: 'id = ?', whereArgs: [id]);
    final flagged = await db.query('clients', where: 'id = ?', whereArgs: [id]);
    expect(flagged.single['requires_manager_approval'], 1);
  });
}
