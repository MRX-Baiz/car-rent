import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A screen that builds its own Scaffold skips the artwork, motion and safe-area
/// handling every other page shares, and the app quietly stops looking like one
/// product. New screens must use `AppPage` (see CLAUDE.md, §9).
///
/// [_legacy] is the backlog of screens that predate it; it may only shrink.
/// A screen that genuinely cannot use the shell (a full-screen camera, say)
/// is added here on purpose, with the reason in review, not by accident.
const _legacy = <String>{
  'assistant/assistant_model_screen.dart',
  'assistant/assistant_screen.dart',
  'clients/client_form_screen.dart',
  'contracts/client_signature_screen.dart',
  'contracts/contract_edit_screen.dart',
  'contracts/contract_form_screen.dart',
  'contracts/contract_pdf_screen.dart',
  'contracts/inspection_form_screen.dart',
  'license/license_screen.dart',
  'lock/lock_screen.dart',
  'lock/pin_recovery_screen.dart',
  'lock/pin_setup_screen.dart',
  'splash/splash_screen.dart',
  'vehicles/vehicle_form_screen.dart',
  'vehicles/vehicle_photos_screen.dart',
};

final _shell = RegExp(r'AppPage|BackdropPage|AmbientListener');

void main() {
  const root = 'lib/presentation/screens/';
  final screens = Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path.replaceFirst(root, ''))
      .toList()
    ..sort();

  test('every new screen is built on AppPage', () {
    final offenders = [
      for (final path in screens)
        if (!_legacy.contains(path) &&
            File('$root$path').readAsStringSync().contains('Scaffold(') &&
            !_shell.hasMatch(File('$root$path').readAsStringSync()))
          path,
    ];

    expect(
      offenders,
      isEmpty,
      reason: 'These screens build their own Scaffold. Use AppPage so they get '
          'the same backdrop, motion and safe-area handling as the rest of '
          'the app: $offenders',
    );
  });

  test('the legacy list only names screens that still need migrating', () {
    final stale = [
      for (final path in _legacy)
        if (!File('$root$path').existsSync() ||
            _shell.hasMatch(File('$root$path').readAsStringSync()))
          path,
    ];

    expect(
      stale,
      isEmpty,
      reason: 'Remove these from _legacy — they were deleted or now use the '
          'shared page shell: $stale',
    );
  });
}
