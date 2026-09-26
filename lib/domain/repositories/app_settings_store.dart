import '../entities/company_profile.dart';

/// Application settings required by business and presentation workflows.
abstract interface class AppSettingsStore {
  Future<CompanyProfile> loadCompanyProfile();
  Future<void> saveCompanyProfile(CompanyProfile profile);

  Future<String> getLanguage();
  Future<void> setLanguage(String languageCode);

  /// Removes obsolete login keys left by versions that had no real login.
  Future<void> clearLegacyAuthSession();
}
