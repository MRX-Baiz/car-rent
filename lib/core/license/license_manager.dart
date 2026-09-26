import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../data/models/license_model.dart';
import 'asymmetric_crypto_helper.dart';

class LicenseManager {
  static const String _licenseFileName = '.app_license.bin';
  static const String _internalSalt = 'car_rent_manager_secure_2026_file_salt';

  final _deviceInfo = DeviceInfoPlugin();

  /// Gets the path to the license file.
  Future<File> _getStorageFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_licenseFileName');
  }

  /// Simple encryption/obfuscation using DeviceID as key.
  Future<String> _secureData(String data) async {
    final key = await getDeviceId();
    final bytes = utf8.encode(data);
    final keyBytes = utf8.encode(key);
    final result = List<int>.filled(bytes.length, 0);
    for (var i = 0; i < bytes.length; i++) {
      result[i] = bytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return base64.encode(result);
  }

  /// Simple decryption/de-obfuscation using DeviceID as key.
  Future<String> _unsecureData(String secured) async {
    try {
      final key = await getDeviceId();
      final bytes = base64.decode(secured);
      final keyBytes = utf8.encode(key);
      final result = List<int>.filled(bytes.length, 0);
      for (var i = 0; i < bytes.length; i++) {
        result[i] = bytes[i] ^ keyBytes[i % keyBytes.length];
      }
      return utf8.decode(result);
    } catch (_) {
      return '';
    }
  }

  /// Saves data to the encrypted local file.
  Future<void> _writeToStorage(Map<String, String> data) async {
    final file = await _getStorageFile();
    final jsonStr = json.encode(data);
    final secured = await _secureData(jsonStr);
    await file.writeAsString(secured);
  }

  /// Reads data from the encrypted local file.
  Future<Map<String, String>> _readFromStorage() async {
    final file = await _getStorageFile();
    if (!await file.exists()) return {};
    try {
      final secured = await file.readAsString();
      final jsonStr = await _unsecureData(secured);
      return Map<String, String>.from(json.decode(jsonStr) as Map);
    } catch (_) {
      return {};
    }
  }

  /// Gets a unique ID for the current hardware.
  Future<String> getDeviceId() async {
    if (Platform.isMacOS) {
      final macInfo = await _deviceInfo.macOsInfo;
      return macInfo.systemGUID ?? 'macos_id';
    } else if (Platform.isWindows) {
      final winInfo = await _deviceInfo.windowsInfo;
      return winInfo.deviceId;
    } else if (Platform.isAndroid) {
      // Settings.Secure.ANDROID_ID: unique per device+app-signing-key and
      // stable across reinstalls. AndroidDeviceInfo exposes no per-device
      // identifier — its `id` is Build.ID, the OS build label, which every
      // device on the same Android build shares.
      final androidId = await const AndroidId().getId();
      return androidId ?? 'android_id';
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'ios_id';
    }
    return 'unknown_device';
  }

  /// Saves a new license after verifying it.
  Future<void> saveLicense(String licenseString) async {
    final validation = await verifyLicense(licenseString);
    if (!validation.isValid) {
      throw Exception(validation.error);
    }

    final storage = await _readFromStorage();
    storage['license'] = licenseString;
    await _writeToStorage(storage);

    // Initialize last run on activation
    await _updateLastRunDate();
  }

  /// Verifies the digital signature and device binding of a license string.
  Future<LicenseValidationResult> verifyLicense(String licenseString) async {
    try {
      final package = LicensePackage.decode(licenseString);

      // 1. Verify Digital Signature
      final isSignatureValid = await AsymmetricCryptoHelper.verify(
        package.data.toJson(),
        package.signature,
        AsymmetricCryptoHelper.publicKeyPem,
      );
      if (!isSignatureValid) {
        return LicenseValidationResult.invalid(
            'Signature de licence invalide.');
      }

      // 2. Hardware Binding
      final currentDevice = await getDeviceId();
      if (package.data.deviceId != currentDevice) {
        return LicenseValidationResult.invalid(
            'Cette licence n\'est pas destinée à cet appareil.');
      }

      // 3. Expiry Date
      if (package.data.expiryDate.isBefore(DateTime.now())) {
        return LicenseValidationResult.invalid(
            'La licence a expiré le ${package.data.expiryDate.toString().split(' ').first}.');
      }

      return LicenseValidationResult.valid(package.data);
    } catch (e) {
      return LicenseValidationResult.invalid('Format de licence corrompu.');
    }
  }

  /// Validates the license and checks for clock tampering (rollback).
  Future<LicenseValidationResult> validateRuntime() async {
    final storage = await _readFromStorage();
    final licenseString = storage['license'];

    if (licenseString == null) {
      return LicenseValidationResult.invalid('Aucune licence trouvée.');
    }

    final verification = await verifyLicense(licenseString);
    if (!verification.isValid) return verification;

    // 4. Time Tampering (Rollback check)
    final storedDateStr = storage['last_run'];
    final storedHash = storage['last_run_hash'];

    if (storedDateStr != null && storedHash != null) {
      final expectedHash =
          AsymmetricCryptoHelper.hashData(storedDateStr, _internalSalt);
      if (storedHash != expectedHash) {
        return LicenseValidationResult.invalid(
            'Détection d\'altération du système de sécurité.');
      }

      final lastRun = DateTime.parse(storedDateStr);
      if (DateTime.now().isBefore(lastRun)) {
        return LicenseValidationResult.invalid(
            'Détection d\'un changement d\'heure système (Clock Rollback).');
      }
    }

    // Update last run date for next launch
    await _updateLastRunDate();
    return verification;
  }

  Future<void> _updateLastRunDate() async {
    final storage = await _readFromStorage();
    final nowStr = DateTime.now().toIso8601String();
    final hash = AsymmetricCryptoHelper.hashData(nowStr, _internalSalt);

    storage['last_run'] = nowStr;
    storage['last_run_hash'] = hash;
    await _writeToStorage(storage);
  }

  Future<bool> isLicenseActive() async {
    final result = await validateRuntime();
    return result.isValid;
  }
}

class LicenseValidationResult {
  final bool isValid;
  final LicenseData? data;
  final String? error;

  LicenseValidationResult.valid(this.data)
      : isValid = true,
        error = null;
  LicenseValidationResult.invalid(this.error)
      : isValid = false,
        data = null;
}
