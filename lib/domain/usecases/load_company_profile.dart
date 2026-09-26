import '../entities/company_profile.dart';
import '../repositories/app_settings_store.dart';

class LoadCompanyProfile {
  const LoadCompanyProfile(this._store);

  final AppSettingsStore _store;

  Future<CompanyProfile> call() => _store.loadCompanyProfile();
}
