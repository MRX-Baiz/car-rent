import 'package:car_rent_manager/core/notifications/notification_preferences.dart';
import 'package:car_rent_manager/core/notifications/notification_service.dart';
import 'package:car_rent_manager/data/repositories/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String> getString(String key, {String defaultValue = ''}) async =>
      values[key] ?? defaultValue;

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> deleteString(String key) async {
    values.remove(key);
  }
}

void main() {
  late tz.Location casablanca;

  setUpAll(() {
    tzdata.initializeTimeZones();
    // The service used to pin tz.local to UTC. Morocco sits an hour ahead, so
    // these tests run in a zone where that mistake is visible.
    casablanca = tz.getLocation('Africa/Casablanca');
  });

  group('quiet window', () {
    test('a window that wraps midnight covers both sides of it', () {
      const preferences = NotificationPreferences(
        quietHoursEnabled: true,
        quietStartHour: 22,
        quietEndHour: 7,
      );

      expect(preferences.isQuiet(23), isTrue);
      expect(preferences.isQuiet(2), isTrue);
      expect(preferences.isQuiet(6), isTrue);
      expect(preferences.isQuiet(7), isFalse, reason: 'the end hour is awake');
      expect(preferences.isQuiet(12), isFalse);
      expect(preferences.isQuiet(21), isFalse);
    });

    test('a daytime window does not wrap', () {
      const preferences = NotificationPreferences(
        quietHoursEnabled: true,
        quietStartHour: 13,
        quietEndHour: 15,
      );

      expect(preferences.isQuiet(14), isTrue);
      expect(preferences.isQuiet(12), isFalse);
      expect(preferences.isQuiet(16), isFalse);
      expect(preferences.isQuiet(1), isFalse);
    });

    test('nothing is quiet while the option is off', () {
      const preferences = NotificationPreferences(
        quietStartHour: 22,
        quietEndHour: 7,
      );
      expect(preferences.isQuiet(23), isFalse);
      expect(preferences.isQuiet(3), isFalse);
    });

    test('an empty window is not permanently quiet', () {
      const preferences = NotificationPreferences(
        quietHoursEnabled: true,
        quietStartHour: 8,
        quietEndHour: 8,
      );
      for (var hour = 0; hour < 24; hour++) {
        expect(preferences.isQuiet(hour), isFalse, reason: 'hour $hour');
      }
    });
  });

  group('applyQuietHours', () {
    const nightly = NotificationPreferences(
      quietHoursEnabled: true,
      quietStartHour: 22,
      quietEndHour: 7,
    );

    test('a late-evening reminder waits for the next morning', () {
      final when = tz.TZDateTime(casablanca, 2026, 8, 12, 23, 30);
      final moved = NotificationService.applyQuietHours(when, nightly);

      expect(moved, tz.TZDateTime(casablanca, 2026, 8, 13, 7));
    });

    test('an early-morning reminder waits for the same morning', () {
      final when = tz.TZDateTime(casablanca, 2026, 8, 12, 3);
      final moved = NotificationService.applyQuietHours(when, nightly);

      expect(moved, tz.TZDateTime(casablanca, 2026, 8, 12, 7),
          reason: '03:00 must not be pushed a whole day out');
    });

    test('a daytime reminder is left alone', () {
      final when = tz.TZDateTime(casablanca, 2026, 8, 12, 14, 15);
      expect(NotificationService.applyQuietHours(when, nightly), when);
    });

    test('the end hour itself is already awake', () {
      final when = tz.TZDateTime(casablanca, 2026, 8, 12, 7);
      expect(NotificationService.applyQuietHours(when, nightly), when);
    });

    test('a reminder crossing a month boundary lands on the 1st', () {
      final when = tz.TZDateTime(casablanca, 2026, 8, 31, 23, 45);
      final moved = NotificationService.applyQuietHours(when, nightly);

      expect(moved, tz.TZDateTime(casablanca, 2026, 9, 1, 7));
    });

    test('quiet hours off changes nothing', () {
      final when = tz.TZDateTime(casablanca, 2026, 8, 12, 23, 30);
      expect(
        NotificationService.applyQuietHours(
            when, const NotificationPreferences()),
        when,
      );
    });
  });

  group('preferences storage', () {
    late _MemoryStore store;
    late NotificationPreferencesRepository repository;

    setUp(() {
      store = _MemoryStore();
      repository = NotificationPreferencesRepository(store: store);
    });

    test('a fresh install has reminders on with a one-hour lead', () async {
      final loaded = await repository.load();

      expect(loaded.enabled, isTrue);
      expect(loaded.leadMinutes, 60);
      expect(loaded.paymentReminders, isTrue);
      expect(loaded.licenseAlerts, isTrue);
      expect(loaded.quietHoursEnabled, isFalse);
    });

    test('every field round-trips', () async {
      const saved = NotificationPreferences(
        enabled: false,
        leadMinutes: 1440,
        paymentReminders: false,
        licenseAlerts: false,
        quietHoursEnabled: true,
        quietStartHour: 21,
        quietEndHour: 8,
      );
      await repository.save(saved);
      final loaded = await repository.load();

      expect(loaded.enabled, isFalse);
      expect(loaded.leadMinutes, 1440);
      expect(loaded.paymentReminders, isFalse);
      expect(loaded.licenseAlerts, isFalse);
      expect(loaded.quietHoursEnabled, isTrue);
      expect(loaded.quietStartHour, 21);
      expect(loaded.quietEndHour, 8);
    });

    test('a stored false is honoured, not treated as unset', () async {
      await repository.save(const NotificationPreferences(enabled: false));
      expect((await repository.load()).enabled, isFalse,
          reason: 'defaulting to true here would resurrect disabled reminders');
    });

    test('corrupt numbers fall back to the default', () async {
      store.values[NotificationPreferencesRepository.keyLeadMinutes] = 'abc';
      expect((await repository.load()).leadMinutes, 60);
    });
  });

  group('licence warnings', () {
    test('are ordered furthest-out first and are all distinct', () {
      final days = NotificationService.licenseWarningDays;

      expect(days, isNotEmpty);
      expect(days.toSet().length, days.length);
      final sorted = [...days]..sort((a, b) => b.compareTo(a));
      expect(days, sorted);
    });
  });
}
