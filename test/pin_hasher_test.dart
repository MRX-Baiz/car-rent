import 'dart:convert';

import 'package:car_rent_manager/core/security/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  // Published PBKDF2-HMAC-SHA256 vectors. If the implementation drifts, these
  // fail long before anyone's PIN stops working.
  group('PBKDF2-HMAC-SHA256 known answers', () {
    void expectVector({
      required String password,
      required String salt,
      required int iterations,
      required int length,
      required String expected,
    }) {
      final actual = PinHasher.derive(
        password: utf8.encode(password),
        salt: utf8.encode(salt),
        iterations: iterations,
        length: length,
      );
      expect(_hex(actual), expected);
    }

    test('c=1, dkLen=32', () {
      expectVector(
        password: 'password',
        salt: 'salt',
        iterations: 1,
        length: 32,
        expected:
            '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('c=2, dkLen=32', () {
      expectVector(
        password: 'password',
        salt: 'salt',
        iterations: 2,
        length: 32,
        expected:
            'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('c=4096, dkLen=32', () {
      expectVector(
        password: 'password',
        salt: 'salt',
        iterations: 4096,
        length: 32,
        expected:
            'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    // Multi-block: dkLen > 32 exercises the block-concatenation loop.
    test('c=4096, dkLen=40 spans two blocks', () {
      expectVector(
        password: 'passwordPASSWORDpassword',
        salt: 'saltSALTsaltSALTsaltSALTsaltSALTsalt',
        iterations: 4096,
        length: 40,
        expected: '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1'
            'fb8dd53e1c635518c7dac47e9',
      );
    });
  });

  group('constantTimeEquals', () {
    test('matches identical input', () {
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    });

    test('rejects a difference in the last byte', () {
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    });

    test('rejects a length mismatch', () {
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2]), isFalse);
    });
  });

  test('a derivation at the shipped iteration count is not too slow', () {
    final stopwatch = Stopwatch()..start();
    PinHasher.derive(
      password: utf8.encode('123456'),
      salt: utf8.encode('0123456789abcdef'),
    );
    stopwatch.stop();

    // Informational: the phone is several times slower than this machine.
    // ignore: avoid_print
    print('PBKDF2 ${PinHasher.defaultIterations} iterations: '
        '${stopwatch.elapsedMilliseconds} ms on this machine');

    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });
}
