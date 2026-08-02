import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/license/license_manager.dart';
import '../../core/security/pin_hasher.dart';
import '../../core/security/pin_reset_token.dart';
import '../../core/security/recovery_code.dart';
import 'app_settings_repository.dart';
import 'key_value_store.dart';

export 'key_value_store.dart';

/// Result of checking a PIN. Sealed so the caller has to handle the lockout.
sealed class UnlockOutcome {
  const UnlockOutcome();
}

class UnlockSuccess extends UnlockOutcome {
  const UnlockSuccess();
}

class UnlockWrongPin extends UnlockOutcome {
  const UnlockWrongPin({required this.attemptsBeforeLockout});

  /// Zero means the next mistake starts a lockout.
  final int attemptsBeforeLockout;
}

class UnlockLockedOut extends UnlockOutcome {
  const UnlockLockedOut({required this.remaining});

  final Duration remaining;
}

class NoPinConfigured extends UnlockOutcome {
  const NoPinConfigured();
}

/// Local lock for the app: a PIN, optionally backed by the device biometric.
///
/// There is no account and no server. The PIN guards the data on this device if
/// the phone is handed to someone or lost; the licence, not this class, decides
/// whether the app may run at all.
class AuthRepository {
  AuthRepository({
    KeyValueStore? store,
    LocalAuthentication? localAuth,
    DateTime Function()? now,
    Future<String> Function()? deviceId,
  })  : _store = store ?? AppSettingsRepository.instance,
        _localAuth = localAuth ?? LocalAuthentication(),
        _now = now ?? DateTime.now,
        _deviceId = deviceId ?? LicenseManager().getDeviceId;

  static final AuthRepository instance = AuthRepository();

  final KeyValueStore _store;
  final LocalAuthentication _localAuth;
  final DateTime Function() _now;

  /// A reset token is bound to one device, same as a licence key.
  final Future<String> Function() _deviceId;

  static const String keyPinSalt = 'pin_salt';
  static const String keyPinHash = 'pin_hash';
  static const String keyPinIterations = 'pin_iterations';
  static const String keyRecoverySalt = 'recovery_salt';
  static const String keyRecoveryHash = 'recovery_hash';
  static const String keyRecoveryIterations = 'recovery_iterations';

  /// Highest reset-token serial this device has redeemed, so an older token
  /// cannot be replayed.
  static const String keyResetSerial = 'pin_reset_serial';
  static const String keyFailedAttempts = 'pin_failed_attempts';
  static const String keyLockedUntil = 'pin_locked_until';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyAutoLockMinutes = 'auto_lock_minutes';

  /// The PIN length the setup and lock screens enforce.
  static const int pinLength = 6;

  /// Mistakes allowed before the lockout ladder starts.
  static const int freeAttempts = 5;

  /// Backgrounding for less than this does not re-lock. Anything that leaves
  /// the app briefly — the camera and the image picker used by the OCR flow —
  /// would otherwise force the user to re-enter the PIN mid-scan.
  static const int defaultAutoLockMinutes = 1;

  static const List<Duration> _lockoutLadder = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  // ---------------------------------------------------------------- PIN state

  Future<bool> hasPin() async {
    final hash = await _store.getString(keyPinHash);
    final salt = await _store.getString(keyPinSalt);
    return hash.isNotEmpty && salt.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = await _derive(
      pin: pin,
      salt: salt,
      iterations: PinHasher.defaultIterations,
    );

    await _store.setString(keyPinSalt, base64Encode(salt));
    await _store.setString(keyPinHash, base64Encode(hash));
    await _store.setString(
      keyPinIterations,
      PinHasher.defaultIterations.toString(),
    );
    await _resetLockout();
  }

  /// Replaces the PIN only if [currentPin] checks out, so the change-PIN screen
  /// cannot be used to bypass the lock.
  Future<UnlockOutcome> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final outcome = await verifyPin(currentPin);
    if (outcome is UnlockSuccess) {
      await setPin(newPin);
    }
    return outcome;
  }

  Future<UnlockOutcome> verifyPin(String pin) async {
    if (!await hasPin()) {
      return const NoPinConfigured();
    }

    final remaining = await lockoutRemaining();
    if (remaining > Duration.zero) {
      return UnlockLockedOut(remaining: remaining);
    }

    final salt = base64Decode(await _store.getString(keyPinSalt));
    final expected = base64Decode(await _store.getString(keyPinHash));
    final iterations = int.tryParse(
          await _store.getString(keyPinIterations),
        ) ??
        PinHasher.defaultIterations;

    final actual = await _derive(pin: pin, salt: salt, iterations: iterations);

    if (PinHasher.constantTimeEquals(actual, expected)) {
      await _resetLockout();
      return const UnlockSuccess();
    }

    return _recordFailure();
  }

  // ----------------------------------------------------------------- recovery

  Future<bool> hasRecoveryCode() async {
    final hash = await _store.getString(keyRecoveryHash);
    return hash.isNotEmpty;
  }

  /// Mints a code, stores only its hash, and hands back the plaintext for the
  /// one and only time it can ever be shown.
  ///
  /// Storing just the hash means the app genuinely cannot display it again —
  /// which is the point, and why settings offer a fresh code rather than a
  /// reminder of the old one.
  Future<String> generateRecoveryCode() async {
    final code = RecoveryCode.generate();
    final salt = _randomSalt();
    final hash = await _derive(
      pin: code,
      salt: salt,
      iterations: PinHasher.defaultIterations,
    );

    await _store.setString(keyRecoverySalt, base64Encode(salt));
    await _store.setString(keyRecoveryHash, base64Encode(hash));
    await _store.setString(
      keyRecoveryIterations,
      PinHasher.defaultIterations.toString(),
    );
    return code;
  }

  /// Checks a recovery code and, on success, clears the PIN so a new one can
  /// be chosen. Data is untouched: this is a way back in, not a wipe.
  ///
  /// Goes through the same lockout as the PIN — twelve digits are already out
  /// of brute-force reach, but there is no reason to leave the door unlatched.
  Future<UnlockOutcome> redeemRecoveryCode(String input) async {
    if (!await hasRecoveryCode()) {
      return const NoPinConfigured();
    }

    final remaining = await lockoutRemaining();
    if (remaining > Duration.zero) {
      return UnlockLockedOut(remaining: remaining);
    }

    final code = RecoveryCode.normalise(input);
    final salt = base64Decode(await _store.getString(keyRecoverySalt));
    final expected = base64Decode(await _store.getString(keyRecoveryHash));
    final iterations =
        int.tryParse(await _store.getString(keyRecoveryIterations)) ??
            PinHasher.defaultIterations;

    final actual = await _derive(pin: code, salt: salt, iterations: iterations);
    if (!PinHasher.constantTimeEquals(actual, expected)) {
      return _recordFailure();
    }

    // Single use. A code that survived its redemption would stay a permanent
    // key for anyone who photographed the paper it was written on.
    await _clearRecoveryCode();
    await clearPin();
    return const UnlockSuccess();
  }

  /// Redeems a vendor-issued token: the backstop for a customer who lost the
  /// recovery code too.
  Future<ResetTokenOutcome> redeemResetToken(String token) async {
    final outcome = await PinResetToken.verify(
      token,
      deviceId: await _deviceId(),
      lastAcceptedSerial:
          int.tryParse(await _store.getString(keyResetSerial)) ?? 0,
      now: _now(),
    );

    if (outcome is ResetTokenAccepted) {
      await _store.setString(keyResetSerial, outcome.serial.toString());
      await clearPin();
    }
    return outcome;
  }

  /// Drops the PIN and every lockout, leaving all business data in place.
  Future<void> clearPin() async {
    await _store.deleteString(keyPinHash);
    await _store.deleteString(keyPinSalt);
    await _store.deleteString(keyPinIterations);
    await _resetLockout();
  }

  Future<void> _clearRecoveryCode() async {
    await _store.deleteString(keyRecoveryHash);
    await _store.deleteString(keyRecoverySalt);
    await _store.deleteString(keyRecoveryIterations);
  }

  // ------------------------------------------------------------------ lockout

  Future<Duration> lockoutRemaining() async {
    final raw = await _store.getString(keyLockedUntil);
    if (raw.isEmpty) {
      return Duration.zero;
    }
    final until = DateTime.tryParse(raw);
    if (until == null) {
      return Duration.zero;
    }

    final left = until.difference(_now());
    // A negative value also covers the user winding the clock forward; winding
    // it backwards only ever extends their own wait, so it gains them nothing.
    return left.isNegative ? Duration.zero : left;
  }

  Future<UnlockOutcome> _recordFailure() async {
    final failures =
        (int.tryParse(await _store.getString(keyFailedAttempts)) ?? 0) + 1;
    await _store.setString(keyFailedAttempts, failures.toString());

    final penalty = _lockoutFor(failures);
    if (penalty > Duration.zero) {
      await _store.setString(
        keyLockedUntil,
        _now().add(penalty).toIso8601String(),
      );
      return UnlockLockedOut(remaining: penalty);
    }

    return UnlockWrongPin(attemptsBeforeLockout: freeAttempts - failures);
  }

  static Duration _lockoutFor(int failures) {
    // The lockout starts *on* the last free attempt, not after it. Counting
    // from the next one would let a guesser have freeAttempts + 1 tries,
    // because the extra attempt is still checked before the penalty applies.
    final step = failures - freeAttempts + 1;
    if (step <= 0) {
      return Duration.zero;
    }
    return _lockoutLadder[min(step - 1, _lockoutLadder.length - 1)];
  }

  Future<void> _resetLockout() async {
    await _store.deleteString(keyFailedAttempts);
    await _store.deleteString(keyLockedUntil);
  }

  // --------------------------------------------------------------- biometrics

  /// Whether the device has a usable biometric enrolled right now. This can go
  /// from true to false at any time — the user may remove their fingerprints —
  /// so it is re-checked rather than cached.
  Future<bool> biometricAvailable() async {
    try {
      if (!await _localAuth.isDeviceSupported()) {
        return false;
      }
      if (!await _localAuth.canCheckBiometrics) {
        return false;
      }
      return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      // A platform without the plugin should degrade to PIN-only, not crash.
      return false;
    }
  }

  Future<bool> biometricEnabled() async {
    final value = await _store.getString(
      keyBiometricEnabled,
      defaultValue: 'false',
    );
    return value.toLowerCase() == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) =>
      _store.setString(keyBiometricEnabled, enabled.toString());

  /// Returns true only on a successful biometric match. Every failure path —
  /// user cancelled, no hardware, too many attempts — returns false so the
  /// caller simply falls back to the PIN.
  Future<bool> authenticateWithBiometrics({required String reason}) async {
    // A lockout must not be sidestepped by using the fingerprint instead.
    if (await lockoutRemaining() > Duration.zero) {
      return false;
    }
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        // biometricOnly: the device passcode is not an acceptable substitute
        // here, since the point is a second factor separate from the phone lock.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- auto-lock

  Future<int> autoLockMinutes() async {
    final raw = await _store.getString(keyAutoLockMinutes);
    return int.tryParse(raw) ?? defaultAutoLockMinutes;
  }

  Future<void> setAutoLockMinutes(int minutes) =>
      _store.setString(keyAutoLockMinutes, minutes.toString());

  // ------------------------------------------------------------------ helpers

  static Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  /// Runs the derivation off the UI thread; at the shipped iteration count it
  /// takes long enough on a phone to drop frames if left on the main isolate.
  Future<Uint8List> _derive({
    required String pin,
    required List<int> salt,
    required int iterations,
  }) {
    return compute(
      _deriveInIsolate,
      (pin: pin, salt: Uint8List.fromList(salt), iterations: iterations),
    );
  }
}

Uint8List _deriveInIsolate(
  ({String pin, Uint8List salt, int iterations}) request,
) {
  return PinHasher.derive(
    password: utf8.encode(request.pin),
    salt: request.salt,
    iterations: request.iterations,
  );
}
