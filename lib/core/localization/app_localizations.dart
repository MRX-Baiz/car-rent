import 'package:intl/intl.dart';
import "../../l10n/generated/app_messages.dart";
import "catalog_bridge.dart";
export "app_copy.dart";
export "../../l10n/generated/app_messages.dart";
import 'package:flutter/material.dart';

/// The languages offered by CarRent Manager. The persisted value is kept as
/// the ISO language code so it remains stable if labels change later.
enum AppLanguage {
  french('fr', 'Français', 'الفرنسية'),
  english('en', 'English', 'الإنجليزية'),
  arabic('ar', 'العربية', 'العربية');

  const AppLanguage(this.code, this.label, this.arabicLabel);

  final String code;
  final String label;
  final String arabicLabel;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
        (language) => language.code == code,
        orElse: () => AppLanguage.french,
      );
}

/// Translates static French UI copy. Dynamic business data (names, licence
/// keys, amounts, registration plates and contract records) is deliberately
/// left unchanged.
class AppLocalizations {
  const AppLocalizations._();

  static String text(BuildContext context, String source) =>
      translate(Localizations.localeOf(context), source);

  static String translate(Locale locale, String source) {
    final messages = lookupAppMessages(
        locale.languageCode == 'en' || locale.languageCode == 'ar'
            ? locale
            : const Locale('fr'));
    final key = source.startsWith('@')
        ? source
        : legacyMessageKeys[normalizeSource(source)];
    return (key == null ? null : resolveMessage(messages, key)) ??
        _template(locale.languageCode, source) ??
        source;
  }

  static String normalizeSource(String source) => source
      .trim()
      .replaceAll("'", '’')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(RegExp(r'[.。]+$'), '');

  /// Transitional adapters for status helpers that still return French copy.
  /// Screens use AppCopy IDs or generated message methods; no translations
  /// live here. This can be removed when those helpers return typed statuses.
  static String? _template(String languageCode, String source) {
    final locale =
        Locale(['en', 'ar'].contains(languageCode) ? languageCode : 'fr');
    final m = lookupAppMessages(locale);
    final rules = <(String, String Function(RegExpMatch))>[
      (r'^En retard de (\d+) h$', (v) => m.overdueHours(v[1]!)),
      (r'^En retard de (\d+) j$', (v) => m.overdueDays(v[1]!)),
      (r'^Expiré depuis (\d+) j$', (v) => m.expiredDays(v[1]!)),
      (r'^Expire dans (\d+) j$', (v) => m.expiresInDays(v[1]!)),
      (r'^Retour aujourd’hui à (.+)$', (v) => m.returnTodayAt(v[1]!)),
      (r'^Retour demain à (.+)$', (v) => m.returnTomorrowAt(v[1]!)),
      (r'^Retour dans (\d+) j$', (v) => m.returnInDays(v[1]!)),
      (r'^Rendu le (.+)$', (v) => m.returnedOn(v[1]!)),
      (r'^Reste (.+)$', (v) => m.balanceAmount(v[1]!)),
      (r'^Non payé · (.+)$', (v) => m.unpaidAmount(v[1]!)),
      (r'^Permis · (.+)$', (v) => m.licenceStatus(translate(locale, v[1]!))),
      (r'^Durée : (\d+) jour\(s\)$', (v) => m.durationDays(v[1]!)),
      (r'^Total (.+)$', (v) => m.totalAmount(v[1]!)),
      (r'^Voir les (\d+)$', (v) => m.seeCount(v[1]!)),
      (r'^Client #(\d+)$', (v) => m.clientNumber(v[1]!)),
      (r'^Véhicule #(\d+)$', (v) => m.vehicleNumber(v[1]!)),
      (
        r'^Ajouté le (.+) · modifié le (.+)$',
        (v) => m.recordDates(v[1]!, v[2]!)
      ),
      (r'^Année (\d+)$', (v) => m.vehicleYear(v[1]!)),
      (
        r'^(\d+) rappel\(s\) programmé\(s\)\.$',
        (v) => m.scheduledReminderCount(v[1]!)
      ),
      (r'^(\d+) heures? avant$', (v) => m.leadHours(v[1]!)),
      (r'^(\d+) minutes avant$', (v) => m.leadMinutes(v[1]!)),
      (r'^(\d+) j restants$', (v) => m.remainingDayCount(v[1]!)),
      (
        r'^Après (\d+) minutes en arrière-plan$',
        (v) => m.lockDelayMinutes(v[1]!)
      ),
      (
        r'^(\d+) points? à (?:traiter|surveiller)$',
        (v) => m.attentionCount(v[1]!)
      ),
      (
        r'^(\d+) véhicules? · (\d+) disponibles?$',
        (v) => m.fleetCount(v[1]!, v[2]!)
      ),
      (r'^Signé le (.+)$', (v) => m.signedOnDate(v[1]!)),
      (r'^Reçu le (.+)$', (v) => m.receivedOnDate(v[1]!)),
      (r'^(.+) copié\.$', (v) => m.copiedValue(v[1]!)),
      (r'^Dépassée de (.+)$', (v) => m.overdueDistance(v[1]!)),
      (r'^Dans (.+)$', (v) => m.inDistance(v[1]!)),
      (
        r'^Trop de tentatives\. Réessayez dans (.+)\.$',
        (v) => m.retryAfter(translate(locale, v[1]!))
      ),
      (
        r'^Code incorrect\. (\d+) essais? restants?\.$',
        (v) => m.pinAttempts(v[1]!)
      ),
      (r'^(\d+) s$', (v) => m.secondsUnit(v[1]!)),
      (r'^(\d+) min$', (v) => m.minutesUnit(v[1]!)),
    ];
    for (final rule in rules) {
      final match = RegExp(rule.$1).firstMatch(source);
      if (match != null) return rule.$2(match);
    }
    final count = RegExp(r'^(.+) \((\d+)\)$').firstMatch(source);
    if (count != null) {
      final label = translate(locale, count[1]!);
      if (label != count[1]) return '$label (${count[2]})';
    }
    return null;
  }
}

extension AppTranslation on BuildContext {
  String tr(String source) => AppLocalizations.text(this, source);
  String money(num value) => NumberFormat.currency(
        locale: Localizations.localeOf(this).languageCode,
        name: 'MAD',
        symbol:
            Localizations.localeOf(this).languageCode == 'ar' ? 'د.م.' : 'MAD',
        decimalDigits: value % 1 == 0 ? 0 : 2,
      ).format(value);
  String distance(num value) =>
      '${NumberFormat.decimalPattern(Localizations.localeOf(this).languageCode).format(value)} ${Localizations.localeOf(this).languageCode == 'ar' ? 'كم' : 'km'}';
  String trError(Object? error) {
    final source = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Bad state):\s*'), '');
    final translated = tr(source);
    return translated != source
        ? translated
        : messages.unableToCompleteThisActionTryAgain;
  }

  AppMessages get messages => lookupAppMessages(Localizations.localeOf(this));
}
