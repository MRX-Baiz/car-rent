import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';

/// Key-value persistence for app settings (company name, address, etc.).
class AppSettingsRepository {
  AppSettingsRepository._internal();

  static final AppSettingsRepository instance = AppSettingsRepository._internal();

  DatabaseHelper get _db => DatabaseHelper.instance;

  static const String keyCompanyName = 'company_name';
  static const String keyCompanyAddress = 'company_address';
  static const String keyCompanyPhone = 'company_phone';

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

  Future<void> setString(String key, String value) async {
    final db = await _db.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> getCompanyName() =>
      getString(keyCompanyName, defaultValue: 'CarRent Manager');

  Future<String> getCompanyAddress() => getString(keyCompanyAddress);

  Future<String> getCompanyPhone() => getString(keyCompanyPhone);

  Future<void> setCompanyName(String value) => setString(keyCompanyName, value);

  Future<void> setCompanyAddress(String value) =>
      setString(keyCompanyAddress, value);

  Future<void> setCompanyPhone(String value) =>
      setString(keyCompanyPhone, value);
}
