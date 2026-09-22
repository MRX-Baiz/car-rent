import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Closing a contract used to be a one-tap action available at any time. A
/// later rewrite of the contract detail page made it wait on the departure
/// inspection being completed first — a real regression the user caught
/// ("we had that option... now we don't have it?"), not an improvement.
///
/// `_buildActionBar` is private and tightly wired into a screen that (via
/// `ContractSignatureCard` and its own payments future) talks to the database
/// directly rather than through an overridable provider, which makes it
/// impractical to render whole in a plain widget test here (see the
/// "verify-ui-with-test-screenshots" memory note). This checks the source
/// directly instead, the same way `settings_controls_test.dart` guards
/// against a UI rewrite silently dropping a working control.
void main() {
  final source =
      File('lib/presentation/screens/contracts/contract_detail_screen.dart')
          .readAsStringSync();

  String actionBarBody() {
    final start = source.indexOf('Widget _buildActionBar(');
    expect(start, greaterThanOrEqualTo(0),
        reason: '_buildActionBar was renamed or removed');
    final next = source.indexOf('\n  Widget _buildBody(', start);
    expect(next, greaterThan(start));
    return source.substring(start, next);
  }

  test('closing is not hidden behind the departure inspection', () {
    final body = actionBarBody();
    expect(
      body,
      isNot(contains('return const SizedBox.shrink()')),
      reason: 'the action bar must not disappear (and take Close with it) '
          'while the contract progress is still loading',
    );
    final closeCalls = '_closeContract(contract)'.allMatches(body).length;
    expect(closeCalls, greaterThanOrEqualTo(2),
        reason: 'Close must be reachable both before and after the '
            'departure inspection is done, not just after');
  });

  test('the departure/return checklist is still offered alongside it', () {
    final body = actionBarBody();
    expect(body, contains("_openInspection(id, 'departure')"));
    expect(body, contains("_openInspection(id, 'return')"));
  });
}
