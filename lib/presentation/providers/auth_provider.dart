import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/pin_reset_token.dart';
import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository.instance;
});

enum LockStatus {
  /// Storage has not been read yet.
  unknown,

  /// First run, or the PIN was never created.
  needsSetup,

  /// A PIN exists and has not been entered this session.
  locked,

  /// The PIN (or biometric) checked out.
  unlocked,
}

class AuthState {
  const AuthState({
    required this.status,
    this.message,
    this.lockoutRemaining = Duration.zero,
    this.busy = false,
    this.biometricAvailable = false,
  });

  final LockStatus status;

  /// Feedback for the lock screen: wrong PIN, attempts left, lockout notice.
  /// Null clears it — unlike the old copyWith, this is not sticky.
  final String? message;

  final Duration lockoutRemaining;
  final bool busy;
  final bool biometricAvailable;

  bool get isLockedOut => lockoutRemaining > Duration.zero;

  AuthState copyWith({
    LockStatus? status,
    String? message,
    Duration? lockoutRemaining,
    bool? busy,
    bool? biometricAvailable,
  }) {
    return AuthState(
      status: status ?? this.status,
      // Deliberately not `message ?? this.message`: that made it impossible to
      // clear the banner, so an error stayed on screen for the rest of the
      // session. Callers pass the message they want shown, every time.
      message: message,
      lockoutRemaining: lockoutRemaining ?? this.lockoutRemaining,
      busy: busy ?? this.busy,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    );
  }
}

/// Mirrors [AuthState.status] for go_router, which is built at import time and
/// so cannot read a provider. [AuthNotifier] is the only writer; treat this as
/// derived state, never as a second place to set the lock.
final lockSignal = ValueNotifier<LockStatus>(LockStatus.unknown);

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository)
      : super(const AuthState(status: LockStatus.unknown)) {
    refresh();
  }

  final AuthRepository _repository;

  // Every assignment funnels through here, so the router can never be looking
  // at a stale lock status.
  @override
  set state(AuthState value) {
    super.state = value;
    lockSignal.value = value.status;
  }

  /// When the app last went to the background, used to decide whether coming
  /// back should require the PIN again.
  DateTime? _backgroundedAt;

  Future<void> refresh() async {
    final hasPin = await _repository.hasPin();
    final biometric = hasPin &&
        await _repository.biometricEnabled() &&
        await _repository.biometricAvailable();

    if (!mounted) return;
    state = AuthState(
      status: hasPin ? LockStatus.locked : LockStatus.needsSetup,
      lockoutRemaining: await _repository.lockoutRemaining(),
      biometricAvailable: biometric,
    );
  }

  /// Stores the PIN and mints the recovery code, without unlocking yet.
  ///
  /// Unlocking here would let the router move on immediately and the user
  /// would never see the code — which is the only time it can ever be shown.
  /// [completeSetup] finishes the job once they have acknowledged it.
  Future<String> createPinAndRecoveryCode(String pin) async {
    state = state.copyWith(busy: true);
    await _repository.setPin(pin);
    final code = await _repository.generateRecoveryCode();
    if (mounted) {
      state = state.copyWith(busy: false);
    }
    return code;
  }

  void completeSetup() {
    state = const AuthState(status: LockStatus.unlocked);
  }

  /// Clears the PIN so a new one can be chosen. Business data is untouched.
  Future<UnlockOutcome> redeemRecoveryCode(String code) async {
    state = state.copyWith(busy: true);
    final outcome = await _repository.redeemRecoveryCode(code);
    if (!mounted) return outcome;

    if (outcome is UnlockSuccess) {
      // No PIN now, so refresh lands on needsSetup and the guard sends the
      // user to choose a new one.
      await refresh();
      return outcome;
    }

    state = state.copyWith(
      busy: false,
      message: switch (outcome) {
        UnlockLockedOut(:final remaining) =>
          'Trop de tentatives. Réessayez dans ${_formatDuration(remaining)}.',
        NoPinConfigured() => 'Aucun code de récupération n\'a été créé.',
        _ => 'Code de récupération incorrect.',
      },
    );
    return outcome;
  }

  Future<ResetTokenOutcome> redeemResetToken(String token) async {
    state = state.copyWith(busy: true);
    final outcome = await _repository.redeemResetToken(token);
    if (!mounted) return outcome;

    if (outcome is ResetTokenAccepted) {
      await refresh();
      return outcome;
    }

    state = state.copyWith(
      busy: false,
      message: switch (outcome) {
        ResetTokenWrongDevice() =>
          'Ce code a été généré pour un autre appareil.',
        ResetTokenExpired() =>
          'Ce code a expiré. Demandez-en un nouveau au vendeur.',
        ResetTokenReplayed() =>
          'Ce code a déjà été utilisé. Demandez-en un nouveau.',
        ResetTokenForged() =>
          'Ce code n\'est pas valide. Vérifiez la saisie.',
        _ => 'Code illisible. Recopiez-le en entier.',
      },
    );
    return outcome;
  }

  Future<String> regenerateRecoveryCode() =>
      _repository.generateRecoveryCode();

  void clearMessage() => state = state.copyWith(message: null);

  Future<bool> submitPin(String pin) async {
    state = state.copyWith(busy: true);
    final outcome = await _repository.verifyPin(pin);
    if (!mounted) return false;

    switch (outcome) {
      case UnlockSuccess():
        state = state.copyWith(
          status: LockStatus.unlocked,
          busy: false,
          lockoutRemaining: Duration.zero,
        );
        return true;

      case UnlockWrongPin(:final attemptsBeforeLockout):
        state = state.copyWith(
          busy: false,
          message: attemptsBeforeLockout <= 2
              ? 'Code incorrect. $attemptsBeforeLockout '
                  '${attemptsBeforeLockout == 1 ? "essai restant" : "essais restants"}.'
              : 'Code incorrect.',
        );
        return false;

      case UnlockLockedOut(:final remaining):
        state = state.copyWith(
          busy: false,
          lockoutRemaining: remaining,
          message: 'Trop de tentatives. Réessayez dans '
              '${_formatDuration(remaining)}.',
        );
        return false;

      case NoPinConfigured():
        state = state.copyWith(status: LockStatus.needsSetup, busy: false);
        return false;
    }
  }

  Future<bool> tryBiometric() async {
    if (!state.biometricAvailable || state.isLockedOut) {
      return false;
    }
    final ok = await _repository.authenticateWithBiometrics(
      reason: 'Déverrouillez CarRent Manager',
    );
    if (!mounted) return false;

    if (ok) {
      state = state.copyWith(status: LockStatus.unlocked);
    }
    // A refusal is silent on purpose: the user simply types their PIN instead.
    return ok;
  }

  void lock() {
    _backgroundedAt = null;
    state = state.copyWith(status: LockStatus.locked, message: null);
  }

  /// Refreshes the countdown so the lock screen can re-enable itself without
  /// the user restarting the app.
  Future<void> refreshLockout() async {
    final remaining = await _repository.lockoutRemaining();
    if (!mounted) return;
    state = state.copyWith(
      lockoutRemaining: remaining,
      message: remaining > Duration.zero ? state.message : null,
    );
  }

  void noteBackgrounded() {
    if (state.status == LockStatus.unlocked) {
      _backgroundedAt = DateTime.now();
    }
  }

  Future<void> noteResumed() async {
    final since = _backgroundedAt;
    if (state.status != LockStatus.unlocked || since == null) {
      return;
    }
    _backgroundedAt = null;

    final grace = Duration(minutes: await _repository.autoLockMinutes());
    if (DateTime.now().difference(since) >= grace) {
      lock();
    }
  }

  static String _formatDuration(Duration d) {
    if (d.inMinutes < 1) {
      return '${d.inSeconds} s';
    }
    return '${d.inMinutes} min';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
