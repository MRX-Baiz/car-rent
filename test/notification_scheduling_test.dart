import 'dart:io';

import 'package:car_rent_manager/core/database/database_helper.dart';
import 'package:car_rent_manager/core/notifications/notification_preferences.dart';
import 'package:car_rent_manager/core/notifications/notification_service.dart';
import 'package:car_rent_manager/data/repositories/key_value_store.dart';
import 'package:car_rent_manager/presentation/providers/contract_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/timezone.dart' as tz;

class _MemoryStore implements KeyValueStore {
  final values = <String, String>{};

  @override
  Future<String> getString(String key, {String defaultValue = ''}) async =>
      values[key] ?? defaultValue;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> deleteString(String key) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  final service = NotificationService.instance;
  late Directory dbDirectory;
  late NotificationPreferencesRepository preferences;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbDirectory = await Directory.systemTemp.createTemp('notification-test-');
    await databaseFactory.setDatabasesPath(dbDirectory.path);
    calls.clear();
    preferences = NotificationPreferencesRepository(store: _MemoryStore());
    service.preferencesRepositoryForTest = preferences;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
        case 'areNotificationsEnabled':
        case 'canScheduleExactNotifications':
          return true;
        case 'pendingNotificationRequests':
          return <Map<String, Object?>>[];
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    service.appInForeground = true;
    await DatabaseHelper.instance.close();
    await dbDirectory.delete(recursive: true);
  });

  Future<int> insertContract(DateTime due, {String status = 'active'}) async {
    final db = await DatabaseHelper.instance.database;
    final stamp = DateTime.now().toIso8601String();
    final vehicleId = await db.insert('vehicles', {
      'brand': 'Test',
      'model': 'Test',
      'registration_number': 'TEST-$status',
      'year': 2026,
      'created_at': stamp,
      'updated_at': stamp,
    });
    final clientId = await db.insert('clients', {
      'first_name': 'Test',
      'last_name': 'Test',
      'cin': 'CIN-$status',
      'license_number': 'LIC-$status',
      'phone': '0000000000',
      'created_at': stamp,
      'updated_at': stamp,
    });
    return db.insert('contracts', {
      'contract_number': 'TEST-$status',
      'vehicle_id': vehicleId,
      'primary_driver_id': clientId,
      'start_date': stamp,
      'expected_return_date': due.toIso8601String(),
      'total_price': 100,
      'amount_paid': 100,
      'status': status,
      'created_at': stamp,
      'updated_at': stamp,
    });
  }

  test(
      'a short contract has a return alarm now and its first overdue alarm tomorrow',
      () async {
    await service.initialize();
    tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
    final now = tz.TZDateTime.now(tz.local);
    final due = now.add(const Duration(minutes: 3));
    await service.scheduleContractReminders(
      contractId: 7,
      registrationNumber: 'TEST-7',
      startDate: now,
      expectedReturnDate: due,
      remainingAmount: 100,
    );

    final scheduled = calls
        .where((call) => call.method == 'zonedSchedule')
        .map((call) => Map<String, dynamic>.from(call.arguments as Map))
        .toList();
    expect(
        scheduled.map((alarm) => alarm['id']), unorderedEquals([71, 72, 74]));
    final late = scheduled.singleWhere((alarm) => alarm['id'] == 72);
    // Time-only matching selects today's occurrence even if tomorrow was passed.
    expect(late['matchDateTimeComponents'], isNull);
    expect(late['scheduledNotificationRepeatFrequency'], 0);
    final first = DateTime.parse(late['scheduledDateTime'] as String);
    expect(
        first,
        DateTime(due.year, due.month, due.day + 1, due.hour, due.minute,
            due.second));
    expect(late['payload'], '/contracts/7');
    expect(late['timeZoneName'], 'Africa/Casablanca');
    for (final alarm in scheduled.where((alarm) => alarm['id'] != 72)) {
      expect(alarm['matchDateTimeComponents'], isNull);
      expect(alarm['scheduledNotificationRepeatFrequency'], isNull);
    }

    calls.clear();
    await service.cancelContractNotifications(7);
    expect(
        calls
            .where((call) => call.method == 'cancel')
            .map((call) => call.arguments['id']),
        containsAll([71, 72, 74]));
  });

  test(
      'opening the updated app replaces old alarms and clears completed contracts',
      () async {
    final active =
        await insertContract(DateTime.now().add(const Duration(days: 2)));
    final completed = await insertContract(DateTime.now(), status: 'completed');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(contractsProvider.future);
    await container.read(contractsProvider.notifier).restoreReminders();
    final late = calls.singleWhere((call) =>
        call.method == 'zonedSchedule' &&
        call.arguments['id'] == active * 10 + 2);
    expect(late.arguments['matchDateTimeComponents'], isNull);
    expect(late.arguments['scheduledNotificationRepeatFrequency'], 0);
    final cancelled = calls
        .where((call) => call.method == 'cancel')
        .map((call) => call.arguments['id']);
    expect(cancelled, containsAll([active * 10 + 2, completed * 10 + 2]));
    expect(
        calls
            .where((call) => call.method == 'zonedSchedule')
            .any((call) => call.arguments['id'] == completed * 10 + 2),
        isFalse);
    expect(calls.any((call) => call.method.startsWith('request')), isFalse);
  });

  test(
      'leaving the app just after the deadline does not send an overdue digest',
      () async {
    await insertContract(DateTime.now().subtract(const Duration(minutes: 1)));
    service.appInForeground = false;
    await service.notifyLateVehicles();
    expect(
        calls.where(
            (call) => call.method == 'show' || call.method == 'zonedSchedule'),
        isEmpty);
  });

  test('a contract overdue since yesterday still earns a digest', () async {
    await insertContract(DateTime.now().subtract(const Duration(days: 2)));
    service.appInForeground = false;
    await service.notifyLateVehicles();
    expect(
        calls.singleWhere((call) => call.method == 'show').arguments['title'],
        'Véhicule en retard');
  });

  test(
      'quiet hours postpone the first daily overdue alarm without losing its date',
      () async {
    await preferences
        .save(const NotificationPreferences(quietHoursEnabled: true));
    final now = tz.TZDateTime.now(tz.local);
    final due =
        tz.TZDateTime(tz.local, now.year, now.month, now.day + 2, 23, 30);
    await service.scheduleContractReminders(
      contractId: 8,
      registrationNumber: 'TEST-8',
      startDate: now,
      expectedReturnDate: due,
      remainingAmount: 0,
    );
    final late = calls.singleWhere(
        (call) => call.method == 'zonedSchedule' && call.arguments['id'] == 82);
    expect(DateTime.parse(late.arguments['scheduledDateTime'] as String),
        DateTime(due.year, due.month, due.day + 2, 7));
    expect(late.arguments['matchDateTimeComponents'], isNull);
  });

  test('an old active contract schedules its next overdue alarm in the future',
      () async {
    final now = tz.TZDateTime.now(tz.local);
    final due = now.subtract(const Duration(days: 10, minutes: 5));
    await service.scheduleContractReminders(
      contractId: 9,
      registrationNumber: 'TEST-9',
      startDate: due,
      expectedReturnDate: due,
      remainingAmount: 0,
    );
    final scheduled = calls.where((call) => call.method == 'zonedSchedule');
    expect(scheduled.length, 1);
    final alarm = scheduled.single.arguments as Map;
    expect(alarm['id'], 92);
    expect(
        DateTime.parse(alarm['scheduledDateTime'] as String),
        DateTime(now.year, now.month, now.day + 1, due.hour, due.minute,
            due.second));
  });
}
