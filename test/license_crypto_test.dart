import 'package:flutter_test/flutter_test.dart';
import 'package:car_rent_manager/core/license/asymmetric_crypto_helper.dart';
import 'package:car_rent_manager/data/models/license_model.dart';
import 'package:fast_rsa/fast_rsa.dart';

void main() {
  test('RSA Signature Verification Test', () async {
    // 1. Generate keys
    final keys = await RSA.generate(2048);
    final publicKey = keys.publicKey;
    final privateKey = keys.privateKey;

    // 2. Create data
    final data = LicenseData(
      name: 'Test user',
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      deviceId: 'test_device',
    );
    final dataJson = data.toJson();

    // 3. Sign
    final signature = await RSA.signPSS(
      dataJson,
      Hash.SHA256,
      SaltLength.AUTO,
      privateKey,
    );

    // 4. Verify
    final isValid = await AsymmetricCryptoHelper.verify(
      dataJson,
      signature,
      publicKey,
    );

    expect(isValid, isTrue);

    // 5. Verify with tampered data
    final isTamperedValid = await AsymmetricCryptoHelper.verify(
      '${dataJson}tamper',
      signature,
      publicKey,
    );
    expect(isTamperedValid, isFalse);
  });
}
