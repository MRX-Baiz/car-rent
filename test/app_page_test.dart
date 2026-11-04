import 'dart:io';
import 'dart:ui' as ui;

import 'package:car_rent_manager/core/constants/app_theme.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_card.dart';
import 'package:car_rent_manager/presentation/widgets/layout/app_page.dart';
import 'package:car_rent_manager/presentation/widgets/motion/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [AppPage] is what every new screen is built on, so these tests pin the
/// promises it makes: the same backdrop and motion as Settings and Home, no
/// overflow on a small phone, and nothing left running under reduced motion.
/// Set VISUAL_OUT_DIR to also write screenshots for a human look.
final _outDir = Platform.environment['VISUAL_OUT_DIR'];

Future<void> _frames(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  if (_outDir == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir!).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

List<Widget> _cards(int count) => [
      for (var i = 0; i < count; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: Center(child: Text('Carte ${i + 1}')),
            ),
          ),
        ),
    ];

Future<GlobalKey> _pump(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(1080, 2400),
  bool reduceMotion = false,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(
      // The runner has no system font, so give the bar title the bundled one
      // the phone would use; otherwise it renders as placeholder blocks.
      theme: buildAppTheme().copyWith(
        appBarTheme: buildAppTheme().appBarTheme.copyWith(
              titleTextStyle: buildAppTheme()
                  .appBarTheme
                  .titleTextStyle
                  ?.copyWith(fontFamily: 'Roboto'),
            ),
      ),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: page,
    ),
  ));
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final asset in [
      'assets/backgrounds/bg_body.webp',
      'assets/backgrounds/bg_settings.webp',
      'assets/backgrounds/bg_home_neutral.png',
    ]) {
      await precacheImage(AssetImage(asset), ctx);
    }
  });
  await _frames(tester, 2.0);
  return key;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await loader.load();
  });

  AppBar appBar(WidgetTester tester) =>
      tester.widget<AppBar>(find.byType(AppBar));

  testWidgets('default page: settings backdrop, title block, cards',
      (tester) async {
    final key = await _pump(
      tester,
      AppPage(
        title: 'Clients',
        eyebrow: 'Votre agence',
        subtitle: 'Karim Alami',
        children: _cards(8),
      ),
    );

    expect(tester.takeException(), isNull);
    // The same building blocks Settings and Home are made of.
    expect(find.byType(AmbientListener), findsOneWidget);
    expect(find.byType(AmbientImage), findsOneWidget);
    expect(find.byType(AmbientGlints), findsOneWidget);
    expect(find.byType(ScrollRail), findsOneWidget);
    expect(find.byType(AnimatedTitle), findsOneWidget);
    expect(find.text('Carte 1'), findsOneWidget);
    await _shot(tester, key, 'app_page_content_0_top');

    // The bar is clear at the top, then turns white with the title in it.
    expect(appBar(tester).backgroundColor!.a, 0);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await _frames(tester, 0.6);
    expect(appBar(tester).backgroundColor!.a, 1);
    expect(
        tester
            .widget<Opacity>(find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(Opacity),
            ))
            .opacity,
        1);
    expect(tester.takeException(), isNull);
    await _shot(tester, key, 'app_page_content_1_scrolled');
  });

  testWidgets('hero page: pinned photo header, then the same content',
      (tester) async {
    final key = await _pump(
      tester,
      AppPage.hero(title: 'Paramètres', children: _cards(8)),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SliverPersistentHeader), findsOneWidget);
    expect(find.byType(AppBar), findsNothing,
        reason: 'the hero brings its own collapsing toolbar');
    expect(find.byType(AnimatedTitle), findsOneWidget);
    await _shot(tester, key, 'app_page_hero_0_top');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await _frames(tester, 0.6);
    expect(tester.takeException(), isNull);
    await _shot(tester, key, 'app_page_hero_1_scrolled');
  });

  testWidgets('home page: full-bleed artwork, the page supplies its header',
      (tester) async {
    final key = await _pump(
      tester,
      AppPage.home(
        title: 'MRX-BAIZ',
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Bonjour', style: TextStyle(fontSize: 28)),
          ),
          ..._cards(6),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AnimatedTitle), findsNothing);
    expect(find.text('MRX-BAIZ'), findsOneWidget,
        reason: 'title is in the bar');
    expect(find.text('Bonjour'), findsOneWidget);
    await _shot(tester, key, 'app_page_home_0_top');
  });

  testWidgets('lazy slivers are accepted in place of children', (tester) async {
    await _pump(
      tester,
      AppPage(
        title: 'Liste',
        slivers: [
          SliverList.builder(
            itemCount: 40,
            itemBuilder: (context, i) => ListTile(title: Text('Ligne $i')),
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Ligne 0'), findsOneWidget);
    // Lazy: far rows are not built until scrolled to.
    expect(find.text('Ligne 39'), findsNothing);
  });

  testWidgets('a small phone (360dp) has no overflow, FAB clears the last card',
      (tester) async {
    await _pump(
      tester,
      AppPage(
        title: 'Véhicules',
        subtitle: 'Un sous-titre assez long pour tester le retour à la ligne',
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Nouveau'),
        ),
        children: _cards(6),
      ),
      size: const Size(1080, 1920),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await _frames(tester, 0.6);
    expect(tester.takeException(), isNull);

    final lastCard = tester.getRect(find.text('Carte 6'));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(lastCard.bottom, lessThanOrEqualTo(fab.top),
        reason: 'the last card must be reachable above the button');
  });

  testWidgets('reduced motion: shows everything at once, nothing left running',
      (tester) async {
    await _pump(
      tester,
      AppPage(title: 'Clients', children: _cards(3)),
      reduceMotion: true,
    );

    expect(find.text('Carte 3'), findsOneWidget);
    // Would time out if a ticker or animation were still scheduled.
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  test('children and slivers are mutually exclusive', () {
    expect(() => AppPage(title: 'x'), throwsAssertionError);
    expect(
      () =>
          AppPage(title: 'x', slivers: const [], children: const [SizedBox()]),
      throwsAssertionError,
    );
  });
}
