import '../repositories/app_settings_store.dart';

class ClearLegacyAuthSession {
  const ClearLegacyAuthSession(this._store);

  final AppSettingsStore _store;

  Future<void> call() => _store.clearLegacyAuthSession();
}
