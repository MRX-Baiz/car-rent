import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// A UI rewrite once silently dropped the "lock now" control from Settings. Building the whole screen needs the
/// database, notification and licence plumbing, so this guards the one thing
/// that failed: every control the operator relies on must still be wired up
/// in the screen's source.
void main() {
  final source = File('lib/presentation/screens/settings/settings_screen.dart')
      .readAsStringSync();

  const controls = <String, String>{
    'Verrouiller maintenant': 'authProvider.notifier).lock()',
    'Modifier le code PIN': "'/settings/pin'",
    'Code de récupération': '_regenerateRecoveryCode',
    'Déverrouillage biométrique': '_setBiometric',
    'Verrouillage automatique': '_pickAutoLockDelay',
    'Créer une sauvegarde': '_createBackup',
    'Restaurer une sauvegarde': '_restoreBackup',
    'Rappels de retour': '_updateNotifications',
    'Rappels de paiement': 'paymentReminders',
    'Expiration de la licence': 'licenseAlerts',
    'Heures silencieuses': 'quietHoursEnabled',
    'Prévenir avant': '_pickLeadTime',
    'Appliquer la nouvelle clé': '_saveLicense',
    'Informations de la société': '_saveCompanySettings',
    'Chauffeurs': "'/chauffeurs'",
    'Assistant local': "'/assistant'",
  };

  controls.forEach((label, wiring) {
    test('Settings keeps "$label" wired to $wiring', () {
      final aliases = jsonDecode(File('lib/l10n/legacy_sources.json').readAsStringSync()) as Map<String, dynamic>;
      final entry = aliases.entries.firstWhere((e) => e.key.startsWith(label.replaceAll("'", '’')));
      expect(source, contains('AppCopy.${entry.value}'), reason: 'the "$label" control is gone');
      expect(source, contains(wiring),
          reason: '"$label" is no longer connected to $wiring');
    });
  });
}
