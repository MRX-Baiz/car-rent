import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256, used to store the app PIN as a salted hash.
///
/// Written out rather than pulled from a package: `crypto` ships HMAC but no
/// key-derivation function, and this is the only place the app needs one.
/// Verified against the published PBKDF2-HMAC-SHA256 vectors in
/// test/pin_hasher_test.dart.
///
/// A 6-digit PIN only has a million combinations, so the iteration count is not
/// what protects it — the lockout in AuthRepository is. Hashing keeps the PIN
/// out of the database in readable form and makes an offline guess cost real
/// time instead of none.
class PinHasher {
  const PinHasher._();

  /// Be honest about what this number buys. Against someone holding the
  /// database file, a six-digit PIN is a million guesses; on GPU hardware no
  /// realistic iteration count turns that into meaningful work. What actually
  /// protects the PIN is Android's per-app storage plus the lockout in
  /// AuthRepository. The iterations only make casual offline guessing cost
  /// something, so the count is set for a comfortable unlock on a low-end
  /// phone rather than pushed as high as it will go — 100k measured 780ms on a
  /// development Mac, which is several seconds on the target hardware.
  ///
  /// Stored next to each hash so it can be raised later without invalidating
  /// PINs created by an older build.
  static const int defaultIterations = 30000;

  static const int keyLength = 32;

  static Uint8List derive({
    required List<int> password,
    required List<int> salt,
    int iterations = defaultIterations,
    int length = keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final blockCount = (length / keyLength).ceil();
    final output = Uint8List(blockCount * keyLength);

    for (var block = 1; block <= blockCount; block++) {
      output.setRange(
        (block - 1) * keyLength,
        block * keyLength,
        _blockAt(hmac, salt, iterations, block),
      );
    }

    return Uint8List.sublistView(output, 0, length);
  }

  /// One PBKDF2 block: U1 = PRF(salt || INT_BE(index)), then XOR of the chain
  /// U1..Uc where each Ui = PRF(Ui-1).
  static Uint8List _blockAt(
    Hmac hmac,
    List<int> salt,
    int iterations,
    int index,
  ) {
    final seed = Uint8List(salt.length + 4)..setRange(0, salt.length, salt);
    ByteData.sublistView(seed, salt.length).setUint32(0, index, Endian.big);

    var u = Uint8List.fromList(hmac.convert(seed).bytes);
    final accumulator = Uint8List.fromList(u);

    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < accumulator.length; j++) {
        accumulator[j] ^= u[j];
      }
    }

    return accumulator;
  }

  /// Compares without leaking, through timing, how far the two matched.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
