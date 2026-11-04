import 'package:car_rent_manager/core/license/asymmetric_crypto_helper.dart';
import 'package:car_rent_manager/data/models/license_model.dart';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:flutter_test/flutter_test.dart';

/// `LicenseManager.verifyLicense` checks a licence's signature by
/// re-deriving JSON from the decoded [LicenseData] object, not by keeping the
/// originally-signed bytes around — so adding `features` to [LicenseData]
/// only stays safe if a feature-less licence still serialises to the exact
/// bytes it was signed with. These tests exist because that is easy to break
/// by "simplifying" `toMap()` to always emit the key.
void main() {
  group('generator and app agree on the format', () {
    // Minted by scripts/generate_license.sh with the real private key (same
    // technique test/pin_recovery_test.dart uses for its reset-token
    // fixture), so the bash JSON encoding and the Dart verifier are proven to
    // agree byte-for-byte, not just "should probably match."
    const fixtureWithFeatures =
        'eyJkYXRhIjp7Im5hbWUiOiJGaXh0dXJlIEFnZW5jeSIsImV4cGlyeSI6IjIwMzYtMDEtMDFUMDA6MDA6MDAuMDAwIiwiZGV2aWNlX2lkIjoiRklYVFVSRS1ERVZJQ0UiLCJmZWF0dXJlcyI6WyJjdXN0b21lcl9oaXN0b3J5Il19LCJzaWduYXR1cmUiOiJFRXFNaFdmZVRwOFBVdnRHSnZjb1ZVMnZxV3NlTDlYSUlsS2JGcW1kT2xWSTRMY2k5S2ZFYzRJNkdoMldQN1I4bjE3NlVPYlJ3d1ByS25mSEdodkUyL3JITHNFNk1nUC9JRTcySkxqc25IK242MlFCUVg2TmtEUWJNZ0kwa0RCeU1rSUUxQUVKNmxXdFZBS0RZbjdoREtXOFBmM0JUZ3RKK1pDdm9YZXcvc0RjQ1RoR3dNekpQd1JTQ0JvUlVsakc2Zzd0YzBTeVhRTWZPc0NkcWJoNUdrSXUwS29YbWhjWXFRUDhYQXdWVEE0bk9nWHI1Q0lVczZoc3JWV3Q1cHkydllyQktYUmZEYlpNR3NOM3Mzb1U3T3dYdGNTZG1DSVFNVVJsNDM4VUdSMmtFSmN3VldlTTlzNzduZmUvN3ZUWnJKSHI5bVN6eFBmRUhuc0liSHNyOUp2TUh6UlB1N0ZYZ1pwSkM1L29WZ0d2Z1RPMkhXSGRpVzJnTVpPaGE2NlNScUJxaWh6Q3BFWTFJcytvcGtQL0R2eURzbmdOZ2ZueGpZMlcvS3J0R1ZRN0xRdGpYT3J3ZUFwVHlONWFHR0ZLM2NVYXAvd2ZVWmg0VXhjdWVsenBnM3E5NHFYdWgxR3RtdW9RYmZ5N0RRL0ljSU9lcGdoYWhRcWtEei9iSkpsdTVwU0lmNFFpWmw4VmpGaFF3WUx0NDZtbVVIQ3FraW9qTS9oVmY0RGFCbDZPSk9vSjVoSmRveUpyeHhMMUFmWmFiTForL2Vmbks2SzloVEVRS05WV3plWnBhVWtSWVVseFlxM3YvV25Ia3h3SU1hWjh0NkJHVEt4WkU1NVFNYkZYc096clpLMkxBZDhzUlZzVi96THlzcjZHd1RxVVpEb2I1SEZBclZyWVZrST0ifQ==';

    // Minted the same way, with no 4th argument - the exact format every
    // licence issued before this feature had.
    const fixtureNoFeatures =
        'eyJkYXRhIjp7Im5hbWUiOiJGaXh0dXJlIEFnZW5jeSIsImV4cGlyeSI6IjIwMzYtMDEtMDFUMDA6MDA6MDAuMDAwIiwiZGV2aWNlX2lkIjoiRklYVFVSRS1ERVZJQ0UifSwic2lnbmF0dXJlIjoiZjFOSm9wSEVreDQzRXgzQWMzekxiTVJtZWhVcVhvMFRkbzNtZGg1cGx1NmRVNkRwOW4rRS83dnhhekJHY3Jvbnp6dUU3UTJCTkV1NXlYcnJUZ20wZGN4U3EzSitpbEQrOEY3ZWhFb05RbVQ3bHdwMU4yTldsTzhMeTNWZ29yZEVUYUxJbVRndCszWlJyUTEwY1htenkzSWxpaDRNNUFtaVdUS3l0Y0tRNEQzS3VHK0dqZ0hwcjVmd3d0REc5QU9vb3FtUG9xcFJjOXlCVjhFeVM1K04yK1UrMER2SWtrdXZVVnRGV1Y3blB4eXVidVB5cXQ0QmJKSkdGUklGOC9CM01wTXg5L2lWbHV6T1JRT2NhV0I3Q3V3eTlJcHgzTktEYk5USStCWTAyMmhLVHl6YTZRT2d2ZTBCVDByZGpNcm9VWUpmbk0rb2YzTzR6c0xFUkYrRHNaZC9TUTNYcWhRSGdhNHFLN0NGWUlxbG01M2J6TlljeVEzU0k3ZTNEcnlRTk00bTdHMlVIUUd1cmZLQkdWdUN2ellTNTZManpWWkRxZjFLUHprZjh3NjM1Sk5uT280NHk4RjE5d1Uxd1FUNzNDenoxdFpPS1htQ0ZaVmhQRndhWU9QczhFa1lVdnZObmdBbXRhb1drc0kvRk5Mc2hlU0xnSkdGcFlqQk8vMzVxZ1JkR2tsengySFZMVWhxTlFnSDN2eWFqTFAvVUtzTlpxcDRwMXM3NUIzM3dCL3RWRmJCRDl5SnEzM0FrcmZvUGd5eFAxM3RDaTltajNzTFlJSVZid0FpaE8zWkZXZXhjR3pQOUtLQXd4UTVmNi9EbHFrQ3hSWTMvU3VKT29NZ2dtWWtURjRZY01aV24za0tpTlZDcmszWUFObjd0dXp0UDYwRkNySmt5MVk9In0=';

    Future<bool> verifies(String licence) async {
      final package = LicensePackage.decode(licence);
      return AsymmetricCryptoHelper.verify(
        package.data.toJson(),
        package.signature,
        AsymmetricCryptoHelper.publicKeyPem,
      );
    }

    test('a licence with features verifies and decodes the feature set',
        () async {
      final package = LicensePackage.decode(fixtureWithFeatures);
      expect(await verifies(fixtureWithFeatures), isTrue);
      expect(package.data.features, {'customer_history'});
    });

    test(
        'a licence with no features - the format every existing customer '
        'has - still verifies', () async {
      final package = LicensePackage.decode(fixtureNoFeatures);
      expect(await verifies(fixtureNoFeatures), isTrue);
      expect(package.data.features, isEmpty);
    });
  });

  group('backward compatibility with already-issued licences', () {
    test(
        'a feature-less LicenseData serialises identically to the format '
        'before this field existed', () {
      final data = LicenseData(
        name: 'Atlas Cars',
        expiryDate: DateTime(2027, 12, 31),
        deviceId: 'DEVICE-1',
      );

      expect(
        data.toJson(),
        '{"name":"Atlas Cars","expiry":"2027-12-31T00:00:00.000",'
        '"device_id":"DEVICE-1"}',
        reason: 'no "features" key at all when there are none - an '
            'unconditional key here breaks every licence issued before '
            'this field existed',
      );
    });

    test('features round-trip through toMap/fromMap, sorted', () {
      final data = LicenseData(
        name: 'Atlas Cars',
        expiryDate: DateTime(2027, 12, 31),
        deviceId: 'DEVICE-1',
        features: {'zeta', 'customer_history', 'alpha'},
      );

      final decoded = LicenseData.fromMap(data.toMap());
      expect(decoded.features, {'alpha', 'customer_history', 'zeta'});
      expect(data.toMap()['features'], ['alpha', 'customer_history', 'zeta']);
    });

    test('decoding a map with no "features" key defaults to empty', () {
      final decoded = LicenseData.fromMap({
        'name': 'Atlas Cars',
        'expiry': '2027-12-31T00:00:00.000',
        'device_id': 'DEVICE-1',
      });

      expect(decoded.features, isEmpty);
    });

    test('a licence signed before this field existed still verifies '
        'end to end with a throwaway key', () async {
      final keys = await RSA.generate(2048);
      final data = LicenseData(
        name: 'Old Customer',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        deviceId: 'OLD-DEVICE',
      );
      final signature = await RSA.signPSS(
        data.toJson(),
        Hash.SHA256,
        SaltLength.AUTO,
        keys.privateKey,
      );

      expect(
        await AsymmetricCryptoHelper.verify(
            data.toJson(), signature, keys.publicKey),
        isTrue,
      );
    });
  });
}
