import 'package:car_rent_manager/app.dart';
import 'package:car_rent_manager/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every screen holding customer data. If the guard lets any of these through
/// while locked, the PIN is decoration.
const _protected = <String>[
  '/dashboard',
  '/vehicles',
  '/vehicles/add',
  '/vehicles/3',
  '/clients',
  '/clients/add',
  '/clients/7',
  '/clients/7/edit',
  '/contracts',
  '/contracts/new',
  '/contracts/12',
  '/settings',
  '/settings/pin',
];

void main() {
  group('while locked', () {
    test('every data screen redirects to the lock screen', () {
      for (final path in _protected) {
        expect(
          lockRedirect(LockStatus.locked, path),
          '/lock',
          reason: '$path must not be reachable with the app locked',
        );
      }
    });

    test('the lock screen itself is allowed', () {
      expect(lockRedirect(LockStatus.locked, '/lock'), isNull);
    });

    test('the licence screen stays reachable', () {
      // Renewing an expired licence has to work before unlocking, otherwise a
      // lapsed licence and a forgotten PIN deadlock each other.
      expect(lockRedirect(LockStatus.locked, '/license'), isNull);
    });
  });

  group('before a PIN exists', () {
    test('every data screen redirects to setup', () {
      for (final path in _protected) {
        expect(
          lockRedirect(LockStatus.needsSetup, path),
          '/pin-setup',
          reason: '$path must not be reachable before a PIN is chosen',
        );
      }
    });

    test('the setup screen itself is allowed', () {
      expect(lockRedirect(LockStatus.needsSetup, '/pin-setup'), isNull);
    });

    test('the lock screen is not an escape hatch', () {
      expect(lockRedirect(LockStatus.needsSetup, '/lock'), '/pin-setup');
    });
  });

  group('before storage has been read', () {
    test('everything waits on the splash', () {
      for (final path in _protected) {
        expect(lockRedirect(LockStatus.unknown, path), '/splash');
      }
      expect(lockRedirect(LockStatus.unknown, '/splash'), isNull);
    });
  });

  group('once unlocked', () {
    test('data screens are reachable', () {
      for (final path in _protected) {
        expect(
          lockRedirect(LockStatus.unlocked, path),
          isNull,
          reason: '$path should open normally when unlocked',
        );
      }
    });

    test('the lock and setup screens hand back to the dashboard', () {
      expect(lockRedirect(LockStatus.unlocked, '/lock'), '/dashboard');
      expect(lockRedirect(LockStatus.unlocked, '/pin-setup'), '/dashboard');
    });

    test('changing the PIN is not treated as first-run setup', () {
      expect(lockRedirect(LockStatus.unlocked, '/settings/pin'), isNull);
    });
  });
}
