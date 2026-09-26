import 'dart:convert';
import 'dart:io';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/core/localization/catalog_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogs = {
    for (final code in ['fr', 'en', 'ar'])
      code: jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map<String, dynamic>,
  };
  test('all three catalogs have exactly the same nonempty messages', () {
    final keys = catalogs['fr']!.keys.where((key) => !key.startsWith('@')).toSet();
    for (final code in catalogs.keys) {
      expect(catalogs[code]!.keys.where((key) => !key.startsWith('@')).toSet(), keys);
      for (final key in keys) {
        expect((catalogs[code]![key] as String).trim(), isNotEmpty, reason: '$code/$key');
      }
    }
  });
  test('every const UI reference resolves in French English and Arabic', () {
    for (final locale in [const Locale('fr'), const Locale('en'), const Locale('ar')]) {
      final messages = lookupAppMessages(locale);
      for (final key in legacyMessageKeys.values.toSet()) {
        expect(resolveMessage(messages, key), isNotNull, reason: '$locale $key');
        expect(AppLocalizations.translate(locale, key), isNot(startsWith('@')));
      }
    }
  });
  test('Settings screenshot regressions use stable IDs and legacy aliases', () {
    for (final source in ["Signature de l'agence", 'Retours prévus, véhicules en retard, paiements.', "Quand un solde reste dû à l'échéance."]) {
      for (final code in ['en', 'ar']) {
        expect(AppLocalizations.translate(Locale(code), source), isNot(source), reason: '$code $source');
      }
    }
    expect(AppLocalizations.translate(const Locale('ar'), AppCopy.agencySignature), 'توقيع الوكالة');
    expect(AppLocalizations.translate(const Locale('en'), AppCopy.agencySignature), 'Agency signature');
  });
  test('generated placeholders preserve customer content verbatim', () {
    const entered = 'Bonjour محمد ABC-123';
    for (final code in ['fr', 'en', 'ar']) {
      final messages = lookupAppMessages(Locale(code));
      expect(messages.removeDriverConfirmation(entered), contains(entered));
      expect(messages.assistantClient(entered), contains(entered));
    }
  });
}
