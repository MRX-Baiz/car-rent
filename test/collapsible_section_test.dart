import 'package:car_rent_manager/core/constants/app_colors.dart';
import 'package:car_rent_manager/presentation/widgets/common/collapsible_section.dart';
import 'package:car_rent_manager/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/french_app.dart';

/// The vehicle and contract detail pages used to show every maintenance
/// date/payment row expanded, all the time, which is exactly the "fills the
/// whole page" complaint this widget exists to fix: collapsed by default,
/// full detail only once the operator asks for it.
void main() {
  Widget host(Widget child) => frenchApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  testWidgets('starts collapsed and opens on tap, badge visible either way',
      (tester) async {
    await tester.pumpWidget(host(const CollapsibleSection(
      title: 'Entretien et documents légaux',
      subtitle: '2 points à surveiller',
      badge: StatusChip(label: '2', tone: AppTone.warning),
      children: [Text('Assurance : expire dans 9 j')],
    )));

    expect(find.text('Assurance : expire dans 9 j'), findsNothing);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Entretien et documents légaux'));
    await tester.pumpAndSettle();

    expect(find.text('Assurance : expire dans 9 j'), findsOneWidget);

    // Tapping again closes it.
    await tester.tap(find.text('Entretien et documents légaux'));
    await tester.pumpAndSettle();
    expect(find.text('Assurance : expire dans 9 j'), findsNothing);
  });

  testWidgets('initiallyExpanded starts open', (tester) async {
    await tester.pumpWidget(host(const CollapsibleSection(
      title: 'Historique des paiements',
      initiallyExpanded: true,
      children: [Text('01/09/2026 — 500 MAD')],
    )));
    expect(find.text('01/09/2026 — 500 MAD'), findsOneWidget);
  });

  testWidgets(
      'wrapInCard:false renders without its own card border, for '
      'nesting inside another card', (tester) async {
    await tester.pumpWidget(host(const CollapsibleSection(
      title: 'Historique des paiements',
      wrapInCard: false,
      children: [Text('Détail')],
    )));
    expect(
        find.ancestor(
            of: find.text('Historique des paiements'),
            matching: find.byType(Card)),
        findsNothing);
  });

  testWidgets('opens instantly under reduced motion, no dangling animation',
      (tester) async {
    await tester.pumpWidget(frenchApp(
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: CollapsibleSection(
            title: 'Entretien et documents légaux',
            children: [Text('Vidange : dans 500 km')],
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Entretien et documents légaux'));
    // A single pump (not pumpAndSettle) is enough when there is no animation
    // to run — if this needs more than one frame, motion wasn't skipped.
    await tester.pump();
    expect(find.text('Vidange : dans 500 km'), findsOneWidget);
  });
}
