/// Result of checking a local app PIN or recovery code.
///
/// This is a business result. It intentionally does not expose hashing,
/// biometric, SQLite, or platform details to the presentation layer.
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
