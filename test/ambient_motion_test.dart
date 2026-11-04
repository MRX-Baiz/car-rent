import 'package:flutter/scheduler.dart';

import 'package:car_rent_manager/presentation/widgets/motion/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal host that owns an [AmbientController] the way a screen does.
class _Host extends StatefulWidget {
  const _Host({required this.onController}) : child = null;
  final ValueChanged<AmbientController> onController;
  final Widget? child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final AmbientController controller;

  @override
  void initState() {
    super.initState();
    controller = AmbientController(vsync: this);
    widget.onController(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AmbientListener(
      controller: controller,
      child: Stack(children: [
        Positioned.fill(
          child: ListView.builder(
            itemCount: 60,
            itemBuilder: (_, i) => SizedBox(height: 80, child: Text('row $i')),
          ),
        ),
        Positioned.fill(child: AmbientGlints(controller: controller)),
      ]),
    );
  }
}

/// Advances time the way a device does: many ~60fps frames, not one big jump
/// (the controller caps a single frame's step so a stalled frame cannot fling
/// everything across the screen).
Future<void> _run(WidgetTester tester, double seconds) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<AmbientController> _pump(WidgetTester tester,
    {bool reduceMotion = false}) async {
  late AmbientController c;
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
          size: const Size(360, 640), disableAnimations: reduceMotion),
      child: Scaffold(body: _Host(onController: (x) => c = x)),
    ),
  ));
  await tester.pump();
  return c;
}

void main() {
  group('AmbientController', () {
    testWidgets('an idle screen stops ticking, so it costs no battery',
        (tester) async {
      final c = await _pump(tester);
      expect(c.isTicking, isTrue, reason: 'entrance drift runs first');

      // Let the entrance finish and everything come to rest.
      await _run(tester, 5);
      await _run(tester, 5);
      expect(c.isSettled, isTrue);
      expect(c.isTicking, isFalse);
    });

    testWidgets('scrolling adds boost, and it fades away when scrolling stops',
        (tester) async {
      final c = await _pump(tester);
      await _run(tester, 6);
      expect(c.boost, lessThan(0.02));

      await tester.fling(find.byType(ListView), const Offset(0, -400), 2500);
      await _run(tester, 0.06);
      final peak = c.boost;
      expect(peak, greaterThan(0.3),
          reason: 'fast scroll should speed things up');
      expect(c.scrollOffset, greaterThan(0));

      await _run(tester, 6);
      await _run(tester, 6);
      expect(c.boost, lessThan(0.05));
      expect(c.isTicking, isFalse);
    });

    testWidgets('a tap sends a ring and gathers glints, which then scatter',
        (tester) async {
      final c = await _pump(tester);
      await _run(tester, 3);

      final spot = tester.getCenter(find.byType(AmbientGlints));
      await tester.tapAt(spot);
      await _run(tester, 0.1);
      expect(c.rings, isNotEmpty, reason: 'the ping shows as a sonar ring');
      expect(c.pingCenter, isNotNull);
      final gathered = c.glints.where((g) => g.gathered).length;
      expect(gathered, greaterThan(2));

      // While the ping is on, gathered glints close in on the touch point.
      await _run(tester, 0.9);
      final near = c.glints
          .where((g) => g.gathered)
          .map((g) => (c.homeOf(g) + Offset(g.dx, g.dy) - spot).distance)
          .fold<double>(0, (a, b) => a + b);
      expect(near / gathered, lessThan(140));

      // Afterwards the ping ends and everyone returns home.
      await _run(tester, 3);
      expect(c.pingCenter, isNull);
      await _run(tester, 6);
      await _run(tester, 6);
      expect(
          c.glints.every((g) => g.dx.abs() < 0.5 && g.dy.abs() < 0.5), isTrue);
      expect(c.isTicking, isFalse);
    });

    testWidgets('glints confined to a hero ignore taps outside it',
        (tester) async {
      final c = await _pump(tester);
      await _run(tester, 3);
      c.clipHeight = 100;

      await tester.tapAt(const Offset(180, 400));
      await _run(tester, 0.3);
      expect(c.pingCenter, isNull, reason: 'the tap was below the hero');
      expect(c.glints.every((g) => !g.gathered), isTrue);

      await tester.tapAt(const Offset(180, 60));
      await _run(tester, 0.3);
      expect(c.pingCenter, isNotNull, reason: 'the tap was inside the hero');
    });

    testWidgets('dragging (scrolling) does not ping', (tester) async {
      final c = await _pump(tester);
      await _run(tester, 3);
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.pingCenter, isNull);
      expect(c.rings, isEmpty);
    });

    testWidgets('reduced motion never starts the ticker or paints',
        (tester) async {
      final c = await _pump(tester, reduceMotion: true);
      await tester.tapAt(tester.getCenter(find.byType(AmbientGlints)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.reduceMotion, isTrue);
      expect(c.isTicking, isFalse);
    });

    test('glints wrap continuously instead of leaving the field', () {
      // Two vsyncs are not needed: step() is driven directly.
      final c = AmbientController(vsync: const _NoTicker());
      c.size = const Size(360, 640);
      for (var i = 0; i < 4000; i++) {
        c.step(1 / 60);
      }
      for (final g in c.glints) {
        expect(g.x, inInclusiveRange(0, 1));
        expect(g.y, inInclusiveRange(0, 1));
      }
      c.dispose();
    });
  });

  group('Reveal', () {
    testWidgets('fades and settles a child into place', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Reveal(index: 2, child: Text('card')),
      ));
      double? opacity() => tester
          .widgetList<Opacity>(find.ancestor(
              of: find.text('card'), matching: find.byType(Opacity)))
          .firstOrNull
          ?.opacity;
      expect(opacity(), lessThan(0.2));
      await tester.pump(const Duration(milliseconds: 250));
      expect(opacity() ?? 1, greaterThan(0.2));
      await tester.pumpAndSettle();
      expect(find.text('card'), findsOneWidget);
      expect(opacity(), isNull, reason: 'no wrapper left once settled');
    });

    testWidgets('shows the child immediately under reduced motion',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Reveal(child: Text('card')),
        ),
      ));
      expect(find.text('card'), findsOneWidget);
      expect(
          find.ancestor(of: find.text('card'), matching: find.byType(Opacity)),
          findsNothing);
    });
  });

  group('CountUpText', () {
    testWidgets('counts up to its value', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CountUpText(value: 40)),
      ));
      expect(find.text('0'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450));
      final mid = int.parse(tester.widget<Text>(find.byType(Text)).data!);
      expect(mid, inInclusiveRange(1, 39));
      await tester.pumpAndSettle();
      expect(find.text('40'), findsOneWidget);
    });

    testWidgets('is instant under reduced motion', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: CountUpText(value: 40)),
        ),
      ));
      expect(find.text('40'), findsOneWidget);
    });
  });
}

class _NoTicker implements TickerProvider {
  const _NoTicker();
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
