import 'package:car_rent_manager/core/constants/app_colors.dart';
import 'package:car_rent_manager/core/constants/app_theme.dart';
import 'package:car_rent_manager/presentation/widgets/dashboard/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The colour a label is actually painted with, after the theme and the
/// widget's DefaultTextStyle have been merged.
Color _paintedColor(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  return paragraph.text.style!.color!;
}

Widget _host(Widget child, {double textScale = 1.0, double width = 360}) {
  return MaterialApp(
    theme: buildAppTheme(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: width, child: child)),
    ),
  );
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('the creamy-copper accent', () {
    final theme = buildAppTheme();

    test('floating buttons use it, with legible dark text', () {
      final fab = theme.floatingActionButtonTheme;
      expect(fab.backgroundColor, AppColors.penny);
      expect(_contrast(fab.foregroundColor!, fab.backgroundColor!),
          greaterThanOrEqualTo(4.5));
    });

    test('the bottom bar uses it, and selected items read on white', () {
      final nav = theme.navigationBarTheme;
      expect(nav.indicatorColor!.toARGB32() & 0x00FFFFFF,
          AppColors.penny.toARGB32() & 0x00FFFFFF);
      final selected = <WidgetState>{WidgetState.selected};
      final icon = nav.iconTheme!.resolve(selected)!.color!;
      final label = nav.labelTextStyle!.resolve(selected)!.color!;
      expect(icon, AppColors.pennyDark);
      expect(_contrast(icon, Colors.white), greaterThanOrEqualTo(4.5));
      expect(_contrast(label, Colors.white), greaterThanOrEqualTo(4.5));
    });
  });

  // An unstyled chip label rendered white on white, so filter chips looked
  // empty on a real phone; these guard the whole family of controls.
  group('control labels are readable on their backgrounds', () {
    testWidgets('chips, outlined, text and segmented buttons are dark',
        (tester) async {
      await tester.pumpWidget(_host(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChoiceChip(
              label: const Text('Tous'), selected: true, onSelected: (_) {}),
          ChoiceChip(
              label: const Text('Loués'), selected: false, onSelected: (_) {}),
          ActionChip(label: const Text('Tout payer'), onPressed: () {}),
          OutlinedButton(onPressed: () {}, child: const Text('Voir')),
          TextButton(onPressed: () {}, child: const Text('Annuler')),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Disponible')),
              ButtonSegment(value: 1, label: Text('Occupé')),
            ],
            selected: const {0},
          ),
        ],
      )));

      for (final label in [
        'Tous',
        'Loués',
        'Tout payer',
        'Voir',
        'Annuler',
        'Disponible',
        'Occupé',
      ]) {
        expect(_paintedColor(tester, label).computeLuminance(), lessThan(0.4),
            reason: '"$label" would be hard to read');
      }
    });

    testWidgets('filled and elevated buttons are light on their blue fill',
        (tester) async {
      await tester.pumpWidget(_host(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(onPressed: () {}, child: const Text('Créer')),
          ElevatedButton(onPressed: () {}, child: const Text('Valider')),
        ],
      )));
      for (final label in ['Créer', 'Valider']) {
        expect(
            _paintedColor(tester, label).computeLuminance(), greaterThan(0.8),
            reason: '"$label" would be hard to read');
      }
    });
  });

  group('dashboard stat cards never overflow', () {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('two-column grid at ${scale}x text on a 360dp phone',
          (tester) async {
        // Mirrors the dashboard: 16dp gutters, 12dp gaps, explicit row height.
        await tester.pumpWidget(_host(
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisExtent: 124 * scale,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: const [
              StatCard(
                  title: 'Disponibles',
                  value: '12',
                  icon: Icons.directions_car),
              StatCard(title: 'Loués', value: '3', icon: Icons.key_outlined),
              StatCard(
                  title: 'Contrats en cours',
                  value: '128',
                  icon: Icons.receipt_long),
              StatCard(title: 'En retard', value: '2', icon: Icons.schedule),
            ],
          ),
          textScale: scale,
          width: 328,
        ));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
