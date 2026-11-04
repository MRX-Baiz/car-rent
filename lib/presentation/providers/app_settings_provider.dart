import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../data/repositories/app_settings_repository.dart';
import '../../domain/repositories/app_settings_store.dart';
import '../../domain/usecases/clear_legacy_auth_session.dart';
import '../../domain/usecases/load_company_profile.dart';
import '../../domain/usecases/save_company_profile.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsRepository.instance;
});

final loadCompanyProfileProvider = Provider<LoadCompanyProfile>((ref) {
  return LoadCompanyProfile(ref.watch(appSettingsRepositoryProvider));
});

final saveCompanyProfileProvider = Provider<SaveCompanyProfile>((ref) {
  return SaveCompanyProfile(ref.watch(appSettingsRepositoryProvider));
});

final clearLegacyAuthSessionProvider = Provider<ClearLegacyAuthSession>((ref) {
  return ClearLegacyAuthSession(ref.watch(appSettingsRepositoryProvider));
});

final companyNameProvider = FutureProvider<String>((ref) async {
  return (await ref.watch(loadCompanyProfileProvider)()).name;
});

final companyAddressProvider = FutureProvider<String>((ref) async {
  return (await ref.watch(loadCompanyProfileProvider)()).address;
});

final companyPhoneProvider = FutureProvider<String>((ref) async {
  return (await ref.watch(loadCompanyProfileProvider)()).phone;
});

final companyLogoProvider = FutureProvider<String>((ref) async {
  return (await ref.watch(loadCompanyProfileProvider)()).logoPath;
});

final companySignatureProvider = FutureProvider<String>((ref) async {
  return (await ref.watch(loadCompanyProfileProvider)()).signaturePath;
});

final appLanguageProvider =
    StateNotifierProvider<AppLanguageController, AppLanguage>((ref) {
  return AppLanguageController(ref.read(appSettingsRepositoryProvider));
});

class AppLanguageController extends StateNotifier<AppLanguage> {
  AppLanguageController(this._repository) : super(AppLanguage.french) {
    unawaited(_restore());
  }

  final AppSettingsStore _repository;

  Future<void> _restore() async {
    state = AppLanguage.fromCode(await _repository.getLanguage());
  }

  Future<void> select(AppLanguage language) async {
    if (state == language) return;
    state = language;
    await _repository.setLanguage(language.code);
  }
}
