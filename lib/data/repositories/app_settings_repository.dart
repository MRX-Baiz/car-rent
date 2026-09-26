import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../domain/entities/company_profile.dart';
import '../../domain/repositories/app_settings_store.dart';
import 'key_value_store.dart';

/// Key-value persistence for app settings (company name, address, etc.).
class AppSettingsRepository implements KeyValueStore, AppSettingsStore {
  AppSettingsRepository._internal();

  static final AppSettingsRepository instance =
      AppSettingsRepository._internal();

  DatabaseHelper get _db => DatabaseHelper.instance;

  static const String keyCompanyName = 'company_name';
  static const String keyCompanyAddress = 'company_address';
  static const String keyCompanyPhone = 'company_phone';
  static const String keyCompanyLogo = 'company_logo';
  static const String keyCompanySignature = 'company_signature';
  static const String keyLanguage = 'app_language';

  /// Left over from the username/password screen that replaced nothing. Kept
  /// only so [clearLegacyAuthSession] can remove them.
  static const List<String> _legacyAuthKeys = <String>[
    'auth_token',
    'logout_on_exit',
    'remember_me',
  ];

  @override
  Future<String> getString(String key, {String defaultValue = ''}) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return defaultValue;
      return rows.first['value'] as String? ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    final db = await _db.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteString(String key) async {
    final db = await _db.database;
    await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<String> getCompanyName() =>
      getString(keyCompanyName, defaultValue: 'CarRent Manager');

  Future<String> getCompanyAddress() => getString(keyCompanyAddress);

  Future<String> getCompanyPhone() => getString(keyCompanyPhone);

  Future<String> getCompanyLogo() => getString(keyCompanyLogo);

  Future<String> getCompanySignature() => getString(keyCompanySignature);

  Future<void> setCompanyName(String value) => setString(keyCompanyName, value);

  Future<void> setCompanyAddress(String value) =>
      setString(keyCompanyAddress, value);

  Future<void> setCompanyPhone(String value) =>
      setString(keyCompanyPhone, value);

  Future<void> setCompanyLogo(String value) => setString(keyCompanyLogo, value);

  Future<void> setCompanySignature(String value) =>
      setString(keyCompanySignature, value);

  @override
  Future<String> getLanguage() => getString(keyLanguage, defaultValue: 'fr');

  @override
  Future<void> setLanguage(String value) => setString(keyLanguage, value);

  @override
  Future<CompanyProfile> loadCompanyProfile() async {
    return CompanyProfile(
      name: await getCompanyName(),
      address: await getCompanyAddress(),
      phone: await getCompanyPhone(),
      logoPath: await getCompanyLogo(),
      signaturePath: await getCompanySignature(),
    );
  }

  @override
  Future<void> saveCompanyProfile(CompanyProfile profile) async {
    await setCompanyName(profile.name);
    await setCompanyAddress(profile.address);
    await setCompanyPhone(profile.phone);
    await setCompanyLogo(profile.logoPath);
    await setCompanySignature(profile.signaturePath);
  }

  /// Drops the keys written by the old username/password session, which never
  /// authenticated anything. Runs once on the first launch after the update so
  /// no stale "logged in" token is left sitting in the database.
  @override
  Future<void> clearLegacyAuthSession() async {
    for (final key in _legacyAuthKeys) {
      await deleteString(key);
    }
  }
}
