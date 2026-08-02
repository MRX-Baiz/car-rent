import 'dart:math';

/// The one-time code shown when the PIN is created, and the only way back in
/// without contacting the vendor.
///
/// Digits rather than words: the same keypad as the PIN, nothing new to learn,
/// and no spelling or language trouble when it is read out over the phone.
class RecoveryCode {
  const RecoveryCode._();

  static const int length = 12;
  static const int _groupSize = 4;

  /// Twelve digits is a trillion combinations, so guessing is hopeless even
  /// before the lockout applies.
  static String generate() {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(10)).join();
  }

  /// `482190375566` becomes `4821 9037 5566`, which is what people copy
  /// without losing their place.
  static String format(String code) {
    final digits = normalise(code);
    final groups = <String>[];
    for (var i = 0; i < digits.length; i += _groupSize) {
      groups.add(
        digits.substring(i, min(i + _groupSize, digits.length)),
      );
    }
    return groups.join(' ');
  }

  /// Strips whatever the user typed down to digits, so a code copied back with
  /// spaces or dashes still matches.
  static String normalise(String input) =>
      input.replaceAll(RegExp(r'[^0-9]'), '');

  static bool isComplete(String input) => normalise(input).length == length;
}
