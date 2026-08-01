/// The slice of settings storage that security code needs, kept separate from
/// [AppSettingsRepository] so tests can supply a plain map instead of standing
/// up a database.
abstract class KeyValueStore {
  Future<String> getString(String key, {String defaultValue = ''});
  Future<void> setString(String key, String value);
  Future<void> deleteString(String key);
}
