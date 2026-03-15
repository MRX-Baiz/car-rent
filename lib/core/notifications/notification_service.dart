import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/database_helper.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        // On unsupported platforms (e.g. Windows) notifications may not be available.
        debugPrint('NotificationService.initialize: $e');
      }
      _initialized = true; // Prevent repeated init attempts
    }
  }

  int _baseIdForContract(int contractId) => contractId * 1000;

  NotificationDetails _buildNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      'car_rent_manager_contracts',
      'Contract Reminders',
      channelDescription: 'Reminders for vehicle return dates and late rentals',
      importance: Importance.max,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  /// Schedule:
  /// 1. One hour before return
  /// 2. At exact return time
  /// 3. Daily if vehicle becomes late (starting the next day after return date)
  Future<void> scheduleReturnReminder({
    required int contractId,
    required String registrationNumber,
    required DateTime returnDate,
  }) async {
    try {
      await initialize();
    } catch (_) {
      return; // Notifications not supported on this platform
    }

    try {
      final details = _buildNotificationDetails();
      final now = DateTime.now();

      final baseId = _baseIdForContract(contractId);

    final tzReturnDate = tz.TZDateTime.from(returnDate, tz.local);
    final tzOneHourBefore =
        tzReturnDate.subtract(const Duration(hours: 1)); // may be in the past

    // 1. One hour before return (only if still in the future)
    if (tzOneHourBefore.isAfter(tz.TZDateTime.from(now, tz.local))) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        baseId,
        'Retour du véhicule',
        'Le véhicule $registrationNumber doit être retourné dans une heure.',
        tzOneHourBefore,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 2. At exact return time (if in the future)
    if (tzReturnDate.isAfter(tz.TZDateTime.from(now, tz.local))) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        baseId + 1,
        'Retour du véhicule',
        'Le véhicule $registrationNumber doit être retourné maintenant.',
        tzReturnDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 3. Daily if late: start the day after expected return at same time.
    final tzFirstLate =
        tzReturnDate.add(const Duration(days: 1)); // first daily reminder

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      baseId + 2,
      'Véhicule en retard',
      'Le véhicule $registrationNumber n’a pas encore été retourné.',
      tzFirstLate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleReturnReminder: $e');
    }
  }

  /// Cancels all notifications associated with a contract.
  Future<void> cancelContractNotifications(int contractId) async {
    try {
      await initialize();
      final baseId = _baseIdForContract(contractId);
      await _flutterLocalNotificationsPlugin.cancel(baseId);
      await _flutterLocalNotificationsPlugin.cancel(baseId + 1);
      await _flutterLocalNotificationsPlugin.cancel(baseId + 2);
    } catch (e) {
      if (kDebugMode) debugPrint('cancelContractNotifications: $e');
    }
  }

  /// Checks for late vehicles and sends an immediate notification for each.
  ///
  /// This is designed to be called periodically (e.g. at app startup).
  Future<void> checkAndNotifyLateVehicles() async {
    try {
      await initialize();
    } catch (_) {
      return;
    }
    final db = await DatabaseHelper.instance.database;

    final nowIso = DateTime.now().toIso8601String();

    // Find active contracts whose expected_return_date is in the past,
    // and join vehicles to get the registration number.
    final result = await db.rawQuery('''
      SELECT c.id AS contract_id, v.registration_number
      FROM contracts c
      JOIN vehicles v ON v.id = c.vehicle_id
      WHERE c.status = 'active' AND c.expected_return_date < ?
    ''', [nowIso]);

    final details = _buildNotificationDetails();

    for (final row in result) {
      final contractId = (row['contract_id'] as int?) ??
          (row['contract_id'] as num).toInt();
      final registrationNumber = row['registration_number'] as String;

      final baseId = _baseIdForContract(contractId);

      await _flutterLocalNotificationsPlugin.show(
        baseId + 3,
        'Véhicule en retard',
        'Le véhicule $registrationNumber est en retard de retour.',
        details,
      );
    }
  }
}

