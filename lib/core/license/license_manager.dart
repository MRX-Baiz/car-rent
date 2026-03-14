import 'dart:convert';

import 'package:sqflite/sqflite.dart' as sqflite;

import 'package:crypto/crypto.dart';

import '../database/database_helper.dart';

class LicenseResult {
  final bool isValid;
  final DateTime? expiryDate;
  final String? companyId;
  final String? errorMessage;

  const LicenseResult({
    required this.isValid,
    this.expiryDate,
    this.companyId,
    this.errorMessage,
  });
}

class LicenseManager {
  static const String _secretKey = 'YOUR_SECRET_KEY_HERE_32CHARS';

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Validates a license key and persists its state to the database.
  ///
  /// Steps:
  /// 1. Parse key into components.
  /// 2. Validate HMAC-SHA256 signature.
  /// 3. Ensure expiry date is in the future.
  /// 4. Enforce anti-rollback using last_verified_date.
  /// 5. Save/refresh license row on success.
  Future<LicenseResult> validateLicense(String licenseKey) async {
    try {
      final parsed = _parseLicenseKey(licenseKey);
      if (parsed == null) {
        return const LicenseResult(
          isValid: false,
          errorMessage: 'Invalid license format.',
        );
      }

      final companyId = parsed['companyId'] as String;
      final expiryDate = parsed['expiryDate'] as DateTime;
      final signature = parsed['signature'] as String;

      final expectedSignature = _computeSignature(companyId, expiryDate);
      if (!_constantTimeEquals(
        expectedSignature.toLowerCase(),
        signature.toLowerCase(),
      )) {
        return const LicenseResult(
          isValid: false,
          errorMessage: 'Invalid license signature.',
        );
      }

      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      final expiryDateOnly =
          DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

      if (!expiryDateOnly.isAfter(todayDateOnly)) {
        return LicenseResult(
          isValid: false,
          expiryDate: expiryDate,
          companyId: companyId,
          errorMessage: 'License has expired.',
        );
      }

      final db = await _dbHelper.database;

      // Anti-rollback: ensure stored last_verified_date <= today.
      final existingRows = await db.query(
        'license_data',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (existingRows.isNotEmpty) {
        final existing = existingRows.first;
        final storedLastVerified =
            DateTime.parse(existing['last_verified_date'] as String);
        final storedDateOnly = DateTime(
          storedLastVerified.year,
          storedLastVerified.month,
          storedLastVerified.day,
        );
        if (todayDateOnly.isBefore(storedDateOnly)) {
          return const LicenseResult(
            isValid: false,
            errorMessage:
                'System date appears to be earlier than the last verification date.',
          );
        }
      }

      // Upsert license record with current verification date.
      final nowIso = today.toIso8601String();
      final expiryIso = expiryDate.toIso8601String();

      await db.insert(
        'license_data',
        {
          'id': 1,
          'license_key': licenseKey,
          'company_id': companyId,
          'expiry_date': expiryIso,
          'last_verified_date': nowIso,
          'is_valid': 1,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );

      return LicenseResult(
        isValid: true,
        expiryDate: expiryDate,
        companyId: companyId,
        errorMessage: null,
      );
    } catch (e) {
      return LicenseResult(
        isValid: false,
        errorMessage: 'License validation failed: $e',
      );
    }
  }

  /// Saves a license key after validating it. Throws if invalid.
  Future<void> saveLicense(String licenseKey) async {
    final result = await validateLicense(licenseKey);
    if (!result.isValid) {
      throw Exception(result.errorMessage ?? 'Invalid license key.');
    }
  }

  /// Returns whether a valid, non-expired license is currently active.
  Future<bool> isLicenseActive() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'license_data',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (rows.isEmpty) return false;

      final row = rows.first;
      final isValid = (row['is_valid'] as int? ?? 0) == 1;
      if (!isValid) return false;

      final expiryDate = DateTime.parse(row['expiry_date'] as String);
      final lastVerified = DateTime.parse(row['last_verified_date'] as String);

      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      final expiryDateOnly =
          DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
      final lastVerifiedDateOnly = DateTime(
        lastVerified.year,
        lastVerified.month,
        lastVerified.day,
      );

      if (!expiryDateOnly.isAfter(todayDateOnly)) {
        return false;
      }
      if (todayDateOnly.isBefore(lastVerifiedDateOnly)) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Generates a license key from a company id and expiry date.
  String generateLicenseKey(String companyId, DateTime expiryDate) {
    final signature = _computeSignature(companyId, expiryDate);
    final yyyy = expiryDate.year.toString().padLeft(4, '0');
    final mm = expiryDate.month.toString().padLeft(2, '0');
    final dd = expiryDate.day.toString().padLeft(2, '0');
    return '$companyId-$yyyy-$mm-$dd-$signature';
  }

  Map<String, Object?>? _parseLicenseKey(String licenseKey) {
    final parts = licenseKey.split('-');
    // Expected: COMPANYID-YYYY-MM-DD-SIGNATURE  => at least 5 parts
    if (parts.length < 5) {
      return null;
    }

    final companyId = parts.first;
    final yearStr = parts[1];
    final monthStr = parts[2];
    final dayStr = parts[3];
    final signature = parts.sublist(4).join('-');

    final year = int.tryParse(yearStr);
    final month = int.tryParse(monthStr);
    final day = int.tryParse(dayStr);

    if (year == null || month == null || day == null) {
      return null;
    }

    try {
      final expiryDate = DateTime(year, month, day);
      return {
        'companyId': companyId,
        'expiryDate': expiryDate,
        'signature': signature,
      };
    } catch (_) {
      return null;
    }
  }

  String _computeSignature(String companyId, DateTime expiryDate) {
    final yyyy = expiryDate.year.toString().padLeft(4, '0');
    final mm = expiryDate.month.toString().padLeft(2, '0');
    final dd = expiryDate.day.toString().padLeft(2, '0');
    final data = '$companyId-$yyyy-$mm-$dd';

    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

