import 'license_manager.dart';

/// Thin wrapper for validating a license key without persisting.
/// Delegates to [LicenseManager.validateLicense].
class LicenseValidator {
  final LicenseManager _manager = LicenseManager();

  /// Validates [licenseKey] and returns [LicenseResult].
  /// Does not update last_verified_date until the caller persists via [LicenseManager.saveLicense].
  Future<LicenseResult> validate(String licenseKey) async {
    return _manager.validateLicense(licenseKey);
  }

  /// Returns true if the format looks like COMPANYID-YYYY-MM-DD-SIGNATURE.
  static bool looksLikeValidFormat(String key) {
    final parts = key.split('-');
    if (parts.length < 5) return false;
    final year = int.tryParse(parts[1]);
    final month = int.tryParse(parts[2]);
    final day = int.tryParse(parts[3]);
    return year != null && month != null && day != null &&
        year >= 2000 && year <= 2100 &&
        month >= 1 && month <= 12 &&
        day >= 1 && day <= 31;
  }
}
