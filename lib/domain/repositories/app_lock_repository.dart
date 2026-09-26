import '../../core/security/pin_reset_token.dart';
import '../entities/unlock_outcome.dart';

/// The local-device security capabilities used by app-lock workflows.
///
/// Its implementation may use encrypted storage and device biometrics, but
/// callers only work with the security rules and their outcomes.
abstract interface class AppLockRepository {
  Future<bool> hasPin();
  Future<void> setPin(String pin);
  Future<UnlockOutcome> changePin({
    required String currentPin,
    required String newPin,
  });
  Future<UnlockOutcome> verifyPin(String pin);

  Future<String> generateRecoveryCode();
  Future<UnlockOutcome> redeemRecoveryCode(String input);
  Future<ResetTokenOutcome> redeemResetToken(String token);

  Future<Duration> lockoutRemaining();

  Future<bool> biometricAvailable();
  Future<bool> biometricEnabled();
  Future<void> setBiometricEnabled(bool enabled);
  Future<bool> authenticateWithBiometrics({required String reason});

  Future<int> autoLockMinutes();
  Future<void> setAutoLockMinutes(int minutes);
}
