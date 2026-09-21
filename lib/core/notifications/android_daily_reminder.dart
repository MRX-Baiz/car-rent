import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// The pinned plugin exposes date-anchored repeats only through its native API.
// ignore: implementation_imports
import 'package:flutter_local_notifications/src/platform_specifics/android/method_channel_mappers.dart';
import 'package:timezone/timezone.dart' as tz;

class AndroidDailyReminder {
  static const _channel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime firstOccurrence,
    required AndroidNotificationDetails details,
    required String route,
  }) async {
    final localDate = DateTime(
      firstOccurrence.year,
      firstOccurrence.month,
      firstOccurrence.day,
      firstOccurrence.hour,
      firstOccurrence.minute,
      firstOccurrence.second,
    );

    // Unlike time-component matching, the native Daily repeat keeps the first
    // date and advances it by calendar days. It uses the plugin's existing
    // cancellation, persistence, boot receiver and notification tap handling.
    await _channel.invokeMethod<void>('zonedSchedule', <String, Object?>{
      'id': id,
      'title': title,
      'body': body,
      'payload': route,
      'timeZoneName': firstOccurrence.location.name,
      'scheduledDateTime': localDate.toIso8601String(),
      'scheduledNotificationRepeatFrequency': 0,
      'platformSpecifics': <String, Object?>{
        ...details.toMap(),
        'scheduleMode': AndroidScheduleMode.exactAllowWhileIdle.name,
      },
    });
  }
}
