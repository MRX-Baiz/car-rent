import 'dart:convert';

import '../license/asymmetric_crypto_helper.dart';

/// Why a reset token was refused. Sealed so the screen has to say something
/// specific — "code invalide" for six different causes is unhelpful when the
/// customer is on the phone with you.
sealed class ResetTokenOutcome {
  const ResetTokenOutcome();
}

class ResetTokenAccepted extends ResetTokenOutcome {
  const ResetTokenAccepted({required this.serial});

  final int serial;
}

class ResetTokenMalformed extends ResetTokenOutcome {
  const ResetTokenMalformed();
}

/// The signature did not verify against the embedded public key: the token was
/// not issued by the vendor, or was altered in transit.
class ResetTokenForged extends ResetTokenOutcome {
  const ResetTokenForged();
}

class ResetTokenWrongDevice extends ResetTokenOutcome {
  const ResetTokenWrongDevice();
}

class ResetTokenExpired extends ResetTokenOutcome {
  const ResetTokenExpired();
}

/// Already used, or older than one that has been. Blocks replay of a token
/// that was screenshotted, forwarded, or read out over a phone line.
class ResetTokenReplayed extends ResetTokenOutcome {
  const ResetTokenReplayed();
}

/// An unlock code issued by the vendor for one device, valid briefly.
///
/// Deliberately shaped like a licence key — same base64-wrapped
/// `{data, signature}` envelope, same RSA-4096 PSS/SHA-256 signature, same
/// private key. That key is the only thing that can mint one, and it never
/// leaves the vendor's machine, so no amount of access to a phone produces a
/// valid token.
class PinResetToken {
  const PinResetToken({
    required this.deviceId,
    required this.serial,
    required this.expiry,
  });

  final String deviceId;

  /// Strictly increasing per device. The app remembers the highest it has
  /// accepted, so an old token cannot be used a second time.
  final int serial;

  final DateTime expiry;

  /// Overridable only so tests can sign with a throwaway key; production
  /// always verifies against the key embedded in the app.
  static const String _publicKey = AsymmetricCryptoHelper.publicKeyPem;

  /// Must match the JSON the generator script signs, byte for byte.
  static String encodeData({
    required String deviceId,
    required int serial,
    required DateTime expiry,
  }) {
    return json.encode(<String, dynamic>{
      'device_id': deviceId,
      'serial': serial,
      'expiry': expiry.toIso8601String(),
    });
  }

  /// Checks signature, device, expiry and replay, in that order.
  ///
  /// [lastAcceptedSerial] is the highest serial this device has already
  /// redeemed; pass 0 when none.
  static Future<ResetTokenOutcome> verify(
    String token, {
    required String deviceId,
    required int lastAcceptedSerial,
    required DateTime now,
    String publicKey = _publicKey,
  }) async {
    final Map<String, dynamic> envelope;
    final String dataJson;
    final String signature;
    try {
      final decoded = utf8.decode(base64.decode(token.trim()));
      envelope = json.decode(decoded) as Map<String, dynamic>;
      // Re-encoding the inner object is what the signature covers, so it has
      // to round-trip through the same encoder the generator mirrors.
      dataJson = json.encode(envelope['data']);
      signature = envelope['signature'] as String;
    } catch (_) {
      return const ResetTokenMalformed();
    }

    if (!await AsymmetricCryptoHelper.verify(dataJson, signature, publicKey)) {
      return const ResetTokenForged();
    }

    final PinResetToken parsed;
    try {
      final data = envelope['data'] as Map<String, dynamic>;
      parsed = PinResetToken(
        deviceId: data['device_id'] as String,
        serial: data['serial'] as int,
        expiry: DateTime.parse(data['expiry'] as String),
      );
    } catch (_) {
      return const ResetTokenMalformed();
    }

    if (parsed.deviceId != deviceId) {
      return const ResetTokenWrongDevice();
    }
    if (!parsed.expiry.isAfter(now)) {
      return const ResetTokenExpired();
    }
    if (parsed.serial <= lastAcceptedSerial) {
      return const ResetTokenReplayed();
    }

    return ResetTokenAccepted(serial: parsed.serial);
  }
}
