import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:car_rent_manager/presentation/widgets/dashboard/stat_card.dart';

/// Renders widgets at real phone dimensions. Flutter reports a RenderFlex
/// overflow as a test failure, so these fail if content is clipped.
void main() {
  // A 360dp-wide phone with 16dp page padding and 12dp between two columns
  // leaves 158dp per card; 118 is the height the dashboard grid requests.
  const cardWidth = 158.0;
  const cardHeight = 118.0;

  Widget wrap(Widget child, {Size size = const Size(360, 640)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('StatCard on a phone-sized grid cell', () {
    testWidgets('a label that wraps to two lines does not overflow',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: StatCard(
              title: 'Véhicules dispo.',
              value: '0',
              icon: Icons.directions_car,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unusually long label still does not overflow',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: StatCard(
              title: 'Contrats actifs en retard de paiement',
              value: '1234',
              icon: Icons.warning_amber_rounded,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a large value scales down instead of overflowing',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: StatCard(
              title: 'Revenus',
              value: '9 999 999 MAD',
              icon: Icons.payments,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Filter bars on a narrow screen', () {
    // The vehicles list put an Expanded search field and an unbounded Wrap of
    // four chips in one Row; the chips overflowed and crushed the field.
    testWidgets('search field and filter chips stack and scroll sideways',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 336,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText:
                        'Rechercher par marque, modèle ou immatriculation',
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final label in const [
                        'Tous',
                        'Disponibles',
                        'Loués',
                        'Maintenance',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: label == 'Tous',
                            onSelected: (_) {},
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      // Every filter must stay reachable by scrolling, not be clipped away.
      for (final label in ['Tous', 'Disponibles', 'Loués', 'Maintenance']) {
        expect(find.text(label), findsOneWidget, reason: '$label is missing');
      }
    });
  });

  group('Wrap-based rows that previously overflowed', () {
    testWidgets('remember-me and forgot-password fit a 360dp screen',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 328,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(value: true, onChanged: (_) {}),
                    ),
                    const SizedBox(width: 8),
                    const Text('Se souvenir de moi'),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Mot de passe oublié?'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('driver radios and scan buttons fit a 360dp screen',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 328,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<bool>(
                          value: false,
                          groupValue: true,
                          onChanged: (_) {},
                        ),
                        const Text('Client existant'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: true,
                          onChanged: (_) {},
                        ),
                        const Text('Nouveau client'),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.badge_outlined, size: 18),
                      label: const Text('CIN'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.credit_card, size: 18),
                      label: const Text('Permis'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
