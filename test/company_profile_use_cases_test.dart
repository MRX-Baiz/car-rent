import 'package:car_rent_manager/domain/entities/company_profile.dart';
import 'package:car_rent_manager/domain/repositories/app_settings_store.dart';
import 'package:car_rent_manager/domain/usecases/clear_legacy_auth_session.dart';
import 'package:car_rent_manager/domain/usecases/load_company_profile.dart';
import 'package:car_rent_manager/domain/usecases/save_company_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('company-profile use cases need only the settings contract', () async {
    final store = _FakeSettingsStore();
    const profile = CompanyProfile(
      name: 'Atlas Cars',
      address: 'Casablanca',
      phone: '+212600000000',
      logoPath: '/media/logo.png',
      signaturePath: '/media/signature.png',
    );

    await SaveCompanyProfile(store)(profile);
    expect(await LoadCompanyProfile(store)(), same(profile));

    await ClearLegacyAuthSession(store)();
    expect(store.legacyAuthWasCleared, isTrue);
  });
}

class _FakeSettingsStore implements AppSettingsStore {
  CompanyProfile _profile = const CompanyProfile(
    name: 'CarRent Manager',
    address: '',
    phone: '',
    logoPath: '',
    signaturePath: '',
  );
  bool legacyAuthWasCleared = false;

  @override
  Future<void> clearLegacyAuthSession() async => legacyAuthWasCleared = true;

  @override
  Future<String> getLanguage() async => 'fr';

  @override
  Future<CompanyProfile> loadCompanyProfile() async => _profile;

  @override
  Future<void> saveCompanyProfile(CompanyProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> setLanguage(String languageCode) async {}
}
