import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_settings_repository.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository.instance;
});

final companyNameProvider = FutureProvider<String>((ref) async {
  return ref.read(appSettingsRepositoryProvider).getCompanyName();
});

final companyAddressProvider = FutureProvider<String>((ref) async {
  return ref.read(appSettingsRepositoryProvider).getCompanyAddress();
});

final companyPhoneProvider = FutureProvider<String>((ref) async {
  return ref.read(appSettingsRepositoryProvider).getCompanyPhone();
});
