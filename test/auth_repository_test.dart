import 'package:car_rent_manager/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the settings table.
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
  // compute() spawns an isolate for the key derivation.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryStore store;
  late DateTime clock;
  late AuthRepository auth;

  setUp(() {
    store = _MemoryStore();
    clock = DateTime(2026, 7, 31, 9);
    auth = AuthRepository(store: store, now: () => clock);
  });

  group('PIN storage', () {
    test('reports no PIN on a fresh install', () async {
      expect(await auth.hasPin(), isFalse);
      expect(await auth.verifyPin('123456'), isA<NoPinConfigured>());
    });

    test('accepts the PIN it was given', () async {
      await auth.setPin('482913');
      expect(await auth.hasPin(), isTrue);
      expect(await auth.verifyPin('482913'), isA<UnlockSuccess>());
    });

    test('rejects a different PIN', () async {
      await auth.setPin('482913');
      expect(await auth.verifyPin('482914'), isA<UnlockWrongPin>());
    });

    test('never writes the PIN itself to storage', () async {
      await auth.setPin('482913');
      expect(
        store.values.values.any((v) => v.contains('482913')),
        isFalse,
        reason: 'the PIN must only exist as a salted hash',
      );
    });

    test('salts each PIN, so the same code hashes differently', () async {
      await auth.setPin('482913');
      final firstHash = store.values[AuthRepository.keyPinHash];
      final firstSalt = store.values[AuthRepository.keyPinSalt];

      await auth.setPin('482913');

      expect(store.values[AuthRepository.keyPinSalt], isNot(firstSalt));
      expect(store.values[AuthRepository.keyPinHash], isNot(firstHash));
    });

    test('honours the iteration count stored with the hash', () async {
      await auth.setPin('482913');
      // Simulates a hash written by a build with a different cost setting.
      store.values[AuthRepository.keyPinIterations] = '1';
      expect(
        await auth.verifyPin('482913'),
        isA<UnlockWrongPin>(),
        reason: 'a different iteration count derives a different key',
      );
    });
  });

  group('changePin', () {
    test('requires the current PIN', () async {
      await auth.setPin('111213');
      final outcome =
          await auth.changePin(currentPin: '999999', newPin: '222324');

      expect(outcome, isA<UnlockWrongPin>());
      expect(await auth.verifyPin('111213'), isA<UnlockSuccess>(),
          reason: 'the old PIN must survive a failed change');
    });

    test('replaces the PIN when the current one is right', () async {
      await auth.setPin('111213');
      final outcome =
          await auth.changePin(currentPin: '111213', newPin: '222324');

      expect(outcome, isA<UnlockSuccess>());
      expect(await auth.verifyPin('222324'), isA<UnlockSuccess>());
      expect(await auth.verifyPin('111213'), isA<UnlockWrongPin>());
    });
  });

  group('lockout', () {
    Future<void> failTimes(int count) async {
      for (var i = 0; i < count; i++) {
        await auth.verifyPin('000000');
      }
    }

    setUp(() async {
      await auth.setPin('482913');
    });

    test('counts down the attempts left', () async {
      final outcome = await auth.verifyPin('000000') as UnlockWrongPin;
      expect(outcome.attemptsBeforeLockout, AuthRepository.freeAttempts - 1);
    });

    test('locks out after the free attempts are used', () async {
      await failTimes(AuthRepository.freeAttempts - 1);
      final outcome = await auth.verifyPin('000000');

      expect(outcome, isA<UnlockLockedOut>());
      expect((outcome as UnlockLockedOut).remaining, const Duration(seconds: 30));
    });

    test('refuses the correct PIN while locked out', () async {
      await failTimes(AuthRepository.freeAttempts);
      expect(
        await auth.verifyPin('482913'),
        isA<UnlockLockedOut>(),
        reason: 'a lockout that the right PIN can end is not a lockout',
      );
    });

    test('accepts the PIN once the lockout expires', () async {
      await failTimes(AuthRepository.freeAttempts);
      clock = clock.add(const Duration(seconds: 31));
      expect(await auth.verifyPin('482913'), isA<UnlockSuccess>());
    });

    test('lengthens the wait on repeated lockouts', () async {
      await failTimes(AuthRepository.freeAttempts);

      final penalties = <Duration>[];
      for (final _ in List.filled(3, null)) {
        clock = clock.add(const Duration(hours: 1));
        final outcome = await auth.verifyPin('000000') as UnlockLockedOut;
        penalties.add(outcome.remaining);
      }

      expect(penalties, const [
        Duration(minutes: 1),
        Duration(minutes: 5),
        Duration(minutes: 15),
      ]);
    });

    test('a success clears the failure history', () async {
      await failTimes(AuthRepository.freeAttempts - 1);
      expect(await auth.verifyPin('482913'), isA<UnlockSuccess>());

      final outcome = await auth.verifyPin('000000') as UnlockWrongPin;
      expect(outcome.attemptsBeforeLockout, AuthRepository.freeAttempts - 1);
    });

    test('winding the clock back does not shorten the lockout', () async {
      await failTimes(AuthRepository.freeAttempts);
      clock = clock.subtract(const Duration(days: 1));

      expect(await auth.verifyPin('482913'), isA<UnlockLockedOut>());
    });

    test('setting a new PIN clears the lockout', () async {
      await failTimes(AuthRepository.freeAttempts);
      await auth.setPin('554433');
      expect(await auth.verifyPin('554433'), isA<UnlockSuccess>());
    });
  });

  group('settings', () {
    test('auto-lock defaults to the grace period', () async {
      expect(
        await auth.autoLockMinutes(),
        AuthRepository.defaultAutoLockMinutes,
      );
    });

    test('auto-lock delay round-trips, including immediate', () async {
      await auth.setAutoLockMinutes(0);
      expect(await auth.autoLockMinutes(), 0);
      await auth.setAutoLockMinutes(15);
      expect(await auth.autoLockMinutes(), 15);
    });

    test('biometrics are off until switched on', () async {
      expect(await auth.biometricEnabled(), isFalse);
      await auth.setBiometricEnabled(true);
      expect(await auth.biometricEnabled(), isTrue);
    });
  });
}
