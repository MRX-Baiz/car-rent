import '../entities/company_profile.dart';
import '../repositories/app_settings_store.dart';

class SaveCompanyProfile {
  const SaveCompanyProfile(this._store);

  final AppSettingsStore _store;

  Future<void> call(CompanyProfile profile) =>
      _store.saveCompanyProfile(profile);
}
