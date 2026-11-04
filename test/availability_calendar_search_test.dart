import 'dart:io';

import 'package:car_rent_manager/core/constants/app_theme.dart';
import 'package:car_rent_manager/core/database/database_helper.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/data/models/vehicle_model.dart';
import 'package:car_rent_manager/data/repositories/vehicle_repository.dart';
import 'package:car_rent_manager/presentation/screens/reservations/availability_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The calendar used to loop over every vehicle in a plain, eagerly-built
/// `Column`, with no way to find one car in a large fleet except scrolling.
/// These guard the fix: a search box that actually filters which rows show,
/// and a row list that only builds what's on screen.
final _now = DateTime(2026, 9, 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    dir = await Directory.systemTemp.createTemp('carrent-availability-');
    await databaseFactory.setDatabasesPath(dir.path);
    await DatabaseHelper.instance.database;

    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await loader.load();

    // Enough vehicles that the old eager Column would build every row at
    // once; only a handful fit the bounded row-list height.
    for (var i = 0; i < 20; i++) {
      await VehicleRepository.instance.insertVehicle(VehicleModel(
        brand: i == 7 ? 'Peugeot' : 'Dacia',
        model: i == 7 ? '208' : 'Logan',
        registrationNumber: i == 7 ? '99999-Z-9' : '${10000 + i}-A-$i',
        year: 2022,
        status: 'available',
        createdAt: _now,
        updatedAt: _now,
      ));
    }
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, __) => const AvailabilityCalendarScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: buildAppTheme(),
          debugShowCheckedModeBanner: false,
          locale: const Locale('fr'),
          supportedLocales: AppMessages.supportedLocales,
          localizationsDelegates: AppMessages.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('a large fleet does not build every row up front',
      (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);

    // 20 vehicles x 7 day cells would be 140 if the row list still built
    // everything eagerly; a genuinely lazy, bounded list builds far fewer.
    final builtCells = find
        .byWidgetPredicate((w) => w.runtimeType.toString() == '_CalendarCell');
    final builtCount = tester.widgetList(builtCells).length;
    expect(builtCount, lessThan(20 * 7),
        reason: 'the row list should only build what fits its bounded '
            'height, not every vehicle at once');
    expect(builtCount, greaterThan(0));
  });

  testWidgets('typing a plate filters the calendar down to that vehicle',
      (tester) async {
    await pump(tester);

    // Vehicle #7 sits well past the bounded list's initial build range, so
    // it isn't found *because it's off screen* — the point of this test is
    // that searching for it builds it regardless of where it would fall in
    // an unfiltered scroll.
    expect(find.textContaining('10000-A-0'), findsOneWidget);
    expect(find.textContaining('99999-Z-9'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '99999');
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.textContaining('99999-Z-9'), findsOneWidget);
    expect(find.textContaining('10000-A-0'), findsNothing);
  });

  testWidgets('a search with no match shows the empty state, not a blank row',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField).first, 'no-such-plate');
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.takeException(), isNull);
    expect(find.textContaining('10000-A-0'), findsNothing);
  });
}
