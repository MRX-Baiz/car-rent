import 'dart:convert';

import 'package:car_rent_manager/core/security/pin_reset_token.dart';
import 'package:car_rent_manager/core/security/recovery_code.dart';
import 'package:car_rent_manager/data/repositories/auth_repository.dart';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:flutter_test/flutter_test.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceId = 'DEVICE-ABC-123';

  late _MemoryStore store;
  late DateTime clock;
  late AuthRepository auth;

  setUp(() {
    store = _MemoryStore();
    clock = DateTime(2026, 8, 2, 10);
    auth = AuthRepository(
      store: store,
      now: () => clock,
      deviceId: () async => deviceId,
    );
  });

  group('recovery code format', () {
    test('is twelve digits', () {
      expect(RecoveryCode.generate(), matches(RegExp(r'^\d{12}$')));
    });

    test('two codes differ', () {
      expect(RecoveryCode.generate(), isNot(RecoveryCode.generate()));
    });

    test('displays in groups of four', () {
      expect(RecoveryCode.format('482190375566'), '4821 9037 5566');
    });

    test('accepts a code typed back with spaces or dashes', () {
      expect(RecoveryCode.normalise('4821 9037 5566'), '482190375566');
      expect(RecoveryCode.normalise('4821-9037-5566'), '482190375566');
    });
  });

  group('recovery code', () {
    setUp(() async {
      await auth.setPin('482913');
    });

    test('does not exist until it is generated', () async {
      expect(await auth.hasRecoveryCode(), isFalse);
      expect(await auth.redeemRecoveryCode('123456789012'),
          isA<NoPinConfigured>());
    });

    test('never stores the code itself', () async {
      final code = await auth.generateRecoveryCode();

      expect(store.values.values.any((v) => v.contains(code)), isFalse,
          reason: 'only the hash may be stored');
    });

    test('clears the PIN and keeps the data reachable', () async {
      final code = await auth.generateRecoveryCode();

      expect(await auth.redeemRecoveryCode(code), isA<UnlockSuccess>());
      expect(await auth.hasPin(), isFalse,
          reason: 'the user is sent to create a new PIN');
    });

    test('accepts the code as it is displayed, with spaces', () async {
      final code = await auth.generateRecoveryCode();

      expect(await auth.redeemRecoveryCode(RecoveryCode.format(code)),
          isA<UnlockSuccess>());
    });

    test('rejects a wrong code and leaves the PIN alone', () async {
      await auth.generateRecoveryCode();

      expect(await auth.redeemRecoveryCode('000000000000'),
          isA<UnlockWrongPin>());
      expect(await auth.hasPin(), isTrue);
    });

    test('is single use', () async {
      final code = await auth.generateRecoveryCode();
      await auth.redeemRecoveryCode(code);
      await auth.setPin('554433');

      expect(await auth.redeemRecoveryCode(code), isA<NoPinConfigured>(),
          reason: 'a redeemed code must never work twice');
      expect(await auth.hasPin(), isTrue);
    });

    test('regenerating invalidates the previous code', () async {
      final first = await auth.generateRecoveryCode();
      final second = await auth.generateRecoveryCode();

      expect(await auth.redeemRecoveryCode(first), isA<UnlockWrongPin>());
      expect(await auth.redeemRecoveryCode(second), isA<UnlockSuccess>());
    });

    test('is covered by the lockout', () async {
      await auth.generateRecoveryCode();
      for (var i = 0; i < AuthRepository.freeAttempts; i++) {
        await auth.redeemRecoveryCode('000000000000');
      }

      expect(await auth.redeemRecoveryCode('000000000000'),
          isA<UnlockLockedOut>());
    });
  });

  group('vendor reset token', () {
    late String publicKey;
    late String privateKey;

    setUpAll(() async {
      final pair = await RSA.generate(2048);
      publicKey = pair.publicKey;
      privateKey = pair.privateKey;
    });

    Future<String> mintToken({
      String device = deviceId,
      int serial = 1,
      Duration validFor = const Duration(hours: 24),
      String? signWith,
    }) async {
      final dataJson = PinResetToken.encodeData(
        deviceId: device,
        serial: serial,
        expiry: clock.add(validFor),
      );
      final signature = await RSA.signPSS(
        dataJson,
        Hash.SHA256,
        SaltLength.AUTO,
        signWith ?? privateKey,
      );
      final envelope = json.encode(<String, dynamic>{
        'data': json.decode(dataJson),
        'signature': signature,
      });
      return base64.encode(utf8.encode(envelope));
    }

    Future<ResetTokenOutcome> verify(String token, {int lastSerial = 0}) {
      return PinResetToken.verify(
        token,
        deviceId: deviceId,
        lastAcceptedSerial: lastSerial,
        now: clock,
        publicKey: publicKey,
      );
    }

    test('a well-formed token is accepted', () async {
      expect(await verify(await mintToken()), isA<ResetTokenAccepted>());
    });

    test('gibberish is rejected as malformed', () async {
      expect(await verify('not-a-token'), isA<ResetTokenMalformed>());
    });

    test('a token signed by anyone else is refused', () async {
      final other = await RSA.generate(2048);
      final token = await mintToken(signWith: other.privateKey);

      expect(await verify(token), isA<ResetTokenForged>(),
          reason: 'only the vendor private key may mint a token');
    });

    test('altered contents break the signature', () async {
      final token = await mintToken(serial: 1);
      final envelope =
          json.decode(utf8.decode(base64.decode(token))) as Map<String, dynamic>;
      (envelope['data'] as Map<String, dynamic>)['serial'] = 99;
      final tampered =
          base64.encode(utf8.encode(json.encode(envelope)));

      expect(await verify(tampered), isA<ResetTokenForged>());
    });

    test('a token for another device is refused', () async {
      final token = await mintToken(device: 'SOMEONE-ELSES-PHONE');
      expect(await verify(token), isA<ResetTokenWrongDevice>());
    });

    test('an expired token is refused', () async {
      final token = await mintToken(validFor: const Duration(hours: 24));
      clock = clock.add(const Duration(hours: 25));

      expect(await verify(token), isA<ResetTokenExpired>(),
          reason: 'a token left in a chat log must go stale on its own');
    });

    test('is still valid just before it lapses', () async {
      final token = await mintToken(validFor: const Duration(hours: 24));
      clock = clock.add(const Duration(hours: 23, minutes: 59));

      expect(await verify(token), isA<ResetTokenAccepted>());
    });

    test('a serial already used is refused', () async {
      final token = await mintToken(serial: 5);
      expect(await verify(token, lastSerial: 5), isA<ResetTokenReplayed>());
    });

    test('a serial older than the last used is refused', () async {
      final token = await mintToken(serial: 3);
      expect(await verify(token, lastSerial: 7), isA<ResetTokenReplayed>());
    });
  });

  // The bash generator and the Dart verifier have to agree byte for byte: the
  // signature covers the exact JSON string, so a reordered key or a different
  // date format silently breaks every token you issue. This fixture was minted
  // by scripts/generate_reset_token.sh with the real private key and is checked
  // against the public key embedded in the app.
  group('generator and app agree on the format', () {
    const fixtureDevice = 'FIXTURE-DEVICE';
    const fixtureToken =
        'eyJkYXRhIjp7ImRldmljZV9pZCI6IkZJWFRVUkUtREVWSUNFIiwic2VyaWFsIjoxNzg1Njc3MDYzLCJleHBpcnkiOiIyMDM2LTA3LTMwVDEzOjI0OjIzLjAwMFoifSwic2lnbmF0dXJlIjoibDlRNWVzbWlTZ1VlR05BVE4zZzJMSkNVNngwd2hHWkJoOG5HNGVIUC9zeGxMSUZJN1FzaVUxYm42ekp2MUU0bFNLdWQrcmJuL0EyOCtERERXWCtvMnY0THRkUGg4R3EyQWFSRXJXT1ErWnoyby9aeGxxR3hRbU1IZ3JKVTBEdkZGT0JWUTBmTm9DT3BxaVRtYUsyajVXNWErZHR3bEVnY3lOMEZQZlkrSHhvRGlScGliVzNEK0IxSG5PUnZiVDNHeFZqWkkwRlVCeWR6ditVZEEyZjBGSmFUaUxYZ1gwSytaelYzTXMzU0tsTEpnWFAzR0VrZjR3dkFNeDNjcVVPUjd0SHgyRTNCVGxiM3k4U21BSU9yT3BBZDN5NzBLR0NhMHFtWVNJTThLNjY1aHBDWkF3WFE3VG5TNHZSTnY3ZFozY2NoOHZ1TXpzM3g0NTQyVldJOXR6Y0VPU1Rad1pCZDJSWW9XaGNJYk80dGZEczhJRVRwWmpPM3E5ck5Jb3plRTAxcTEzYkhiekRFbFg0MEtHU05QQXBoajYwR3dHa0xuMERublhzSHhqTVpwQ0U3Vk1aK09oZ1B0RTJvU0FjNCtnWmtDQkRIZk8vYVMwUWRXS3RKcmlyWXNlOW9xejhrNFBoSEg1N0dHSFZaRHl0bURmbXI2eDhTVHFGcXFQbTl3UlYvZFJXeWo0NGdadEFZLyswYkFIR3BDZW92Y0FPU0dZNkVweEx1R2xHOHNoclhVUXBNaE9TTUcwNmNGMWpkT210dDZRRS9RbHZKWnYrZGZRSE5HUTVtc2RuS3dlU3RRNmVvRDg0NWxsVkpkUSsyVFhGVWI0WHlaeVBZSk9qQ0tEU0tkanlxVWxBVWdqeGpJRS9CaFRCTmZ3VUcyUHowdTYrUnF3L0JVc2M9In0=';

    test('a token from the shell script verifies in the app', () async {
      final outcome = await PinResetToken.verify(
        fixtureToken,
        deviceId: fixtureDevice,
        lastAcceptedSerial: 0,
        now: DateTime.utc(2026, 8, 2),
      );

      expect(outcome, isA<ResetTokenAccepted>(),
          reason: 'the generator JSON must match PinResetToken.encodeData');
    });

    test('the serial the script emits is usable for replay protection',
        () async {
      final accepted = await PinResetToken.verify(
        fixtureToken,
        deviceId: fixtureDevice,
        lastAcceptedSerial: 0,
        now: DateTime.utc(2026, 8, 2),
      ) as ResetTokenAccepted;

      // Epoch seconds, so a later token always outranks an earlier one and
      // the vendor never has to track what they last issued.
      expect(accepted.serial, greaterThan(1700000000));

      final replayed = await PinResetToken.verify(
        fixtureToken,
        deviceId: fixtureDevice,
        lastAcceptedSerial: accepted.serial,
        now: DateTime.utc(2026, 8, 2),
      );
      expect(replayed, isA<ResetTokenReplayed>());
    });
  });

  group('redeeming a reset token', () {
    // The repository path uses the embedded production key, which no test can
    // sign for. What it can prove is that a token it will not accept changes
    // nothing at all.
    setUp(() async {
      await auth.setPin('482913');
    });

    test('an unverifiable token leaves the PIN in place', () async {
      final outcome = await auth.redeemResetToken('bogus');

      expect(outcome, isA<ResetTokenMalformed>());
      expect(await auth.hasPin(), isTrue);
      expect(await auth.verifyPin('482913'), isA<UnlockSuccess>());
    });

    test('a refused token does not advance the serial', () async {
      await auth.redeemResetToken('bogus');

      expect(store.values[AuthRepository.keyResetSerial], isNull,
          reason: 'only a redeemed token may move the replay counter');
    });
  });
}
