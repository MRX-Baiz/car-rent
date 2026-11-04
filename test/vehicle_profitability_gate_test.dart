import 'dart:async';

import 'package:car_rent_manager/core/constants/app_theme.dart';
import 'package:car_rent_manager/core/license/license_features.dart';
import 'package:car_rent_manager/core/license/license_manager.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/data/models/vehicle_model.dart';
import 'package:car_rent_manager/presentation/providers/vehicle_provider.dart';
import 'package:car_rent_manager/presentation/screens/vehicles/vehicle_profitability_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The "Rentabilité" nav icon is hidden without `LicenseFeature.
/// profitability`, but that's only a shortcut — reaching this route directly
/// (a saved link, a typed URL) must not show real business data either. This
/// guards the screen's own check, not just the icon that links to it.
class _Vehicles extends VehicleNotifier {
  _Vehicles(this.items);
  final List<VehicleModel> items;
  @override
  FutureOr<List<VehicleModel>> build() => items;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await loader.load();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehiclesProvider.overrideWith(() => _Vehicles(const [])),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          debugShowCheckedModeBanner: false,
          locale: const Locale('fr'),
          supportedLocales: AppMessages.supportedLocales,
          localizationsDelegates: AppMessages.localizationsDelegates,
          home: const VehicleProfitabilityScreen(),
        ),
      ),
    );
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('without the licence feature, the report is locked, not shown',
      (tester) async {
    licenseFeaturesSignal.value = const {};
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.text("Cette fonctionnalité n'est pas incluse dans votre licence."),
      findsOneWidget,
    );
    expect(find.text('Revenu total'), findsNothing);
  });

  testWidgets('with the licence feature, the real report shows',
      (tester) async {
    licenseFeaturesSignal.value = {LicenseFeature.profitability};
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.text("Cette fonctionnalité n'est pas incluse dans votre licence."),
      findsNothing,
    );
    licenseFeaturesSignal.value = const {};
  });
}
