import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:car_rent_manager/core/constants/app_colors.dart';
import 'package:car_rent_manager/core/constants/app_theme.dart';
import 'package:car_rent_manager/data/models/chauffeur_model.dart';
import 'package:car_rent_manager/data/models/client_model.dart';
import 'package:car_rent_manager/data/models/contract_model.dart';
import 'package:car_rent_manager/data/models/vehicle_model.dart';
import 'package:car_rent_manager/presentation/providers/app_settings_provider.dart';
import 'package:car_rent_manager/presentation/providers/contract_provider.dart';
import 'package:car_rent_manager/presentation/providers/dashboard_provider.dart';
import 'package:car_rent_manager/presentation/providers/lookup_provider.dart';
import 'package:car_rent_manager/presentation/providers/vehicle_provider.dart';
import 'package:car_rent_manager/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:car_rent_manager/presentation/screens/splash/splash_screen.dart';
import 'package:car_rent_manager/presentation/screens/vehicles/vehicle_detail_screen.dart';
import 'package:car_rent_manager/presentation/screens/vehicles/vehicles_list_screen.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_card.dart';
import 'package:car_rent_manager/presentation/widgets/motion/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Renders the real screens, on a phone-sized surface, with test-only sample
/// data. It fails on any layout overflow or exception, and when
/// VISUAL_OUT_DIR is set it also writes screenshots there for a human look.
///
/// The sample data lives here, in tests; production screens never see it.

final _now = DateTime.now();
final _outDir = Platform.environment['VISUAL_OUT_DIR'];

class _FakeVehicles extends VehicleNotifier {
  _FakeVehicles(this.items);
  final List<VehicleModel> items;
  @override
  FutureOr<List<VehicleModel>> build() => items;
  @override
  Future<void> loadVehicles() async {}
}

class _FakeContracts extends ContractNotifier {
  _FakeContracts(this.items);
  final List<ContractModel> items;
  @override
  FutureOr<List<ContractModel>> build() => items;
  @override
  Future<void> loadContracts() async {}
}

class _FakeDashboard extends DashboardNotifier {
  @override
  FutureOr<DashboardStats> build() => DashboardStats(
        availableVehicles: 2,
        rentedVehicles: 1,
        activeContracts: 1,
        lateContracts: 1,
        totalRevenue: 18450,
        weeklyRevenue: [
          for (var i = 0; i < 7; i++)
            MapEntry(_now.subtract(Duration(days: 6 - i)),
                [0.0, 800.0, 0.0, 1500.0, 400.0, 0.0, 2100.0][i]),
        ],
      );
  @override
  Future<void> refresh() async {}
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  await loader.load();
}

List<VehicleModel> _vehicles(Uint8List photo) => [
      VehicleModel(
        id: 1,
        brand: 'Dacia',
        model: 'Logan',
        registrationNumber: '12345-A-6',
        year: 2021,
        status: 'rented',
        imageBytes: photo,
        currentMileage: 84200,
        insuranceExpiryDate: _now.add(const Duration(days: 9)),
        createdAt: _now,
        updatedAt: _now,
      ),
      VehicleModel(
        id: 2,
        brand: 'Peugeot',
        model: '208',
        registrationNumber: '48211-B-1',
        year: 2023,
        status: 'available',
        imageBytes: photo,
        transmission: 'automatic',
        fuelType: 'diesel',
        currentMileage: 21500,
        createdAt: _now,
        updatedAt: _now,
      ),
      VehicleModel(
        id: 3,
        brand: 'Renault',
        model: 'Clio 5',
        registrationNumber: '90211-D-7',
        year: 2022,
        status: 'available',
        imageBytes: photo,
        currentMileage: 39800,
        conditionStatus: 'check',
        createdAt: _now,
        updatedAt: _now,
      ),
    ];

final _contract = ContractModel(
  id: 1,
  contractNumber: 'CTR-20260920-0001',
  vehicleId: 1,
  primaryDriverId: 1,
  startDate: _now.subtract(const Duration(days: 5)),
  expectedReturnDate: _now.subtract(const Duration(hours: 7)),
  totalPrice: 1500,
  amountPaid: 1400,
  status: 'active',
  createdAt: _now,
  updatedAt: _now,
);

Lookups _lookups(List<VehicleModel> vehicles) => Lookups(
      vehicles: {for (final v in vehicles) v.id!: v},
      clients: {
        1: ClientModel(
          id: 1,
          firstName: 'Karim',
          lastName: 'Alami',
          cin: 'AB123456',
          licenseNumber: '33/345678',
          phone: '0612345678',
          createdAt: _now,
          updatedAt: _now,
        ),
      },
      chauffeurs: {
        1: ChauffeurModel(
          id: 1,
          firstName: 'Youssef',
          lastName: 'Bennani',
          cin: 'CD654321',
          licenseNumber: '12/987654',
          phone: '0698765432',
          hourlyRate: 120,
          createdAt: _now,
          updatedAt: _now,
        ),
      },
    );

Future<GlobalKey> _pumpApp(
  WidgetTester tester, {
  required Widget screen,
  required List<Override> overrides,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => screen),
    GoRoute(path: '/dashboard', builder: (_, __) => const SizedBox()),
    GoRoute(path: '/vehicles', builder: (_, __) => const SizedBox()),
    GoRoute(path: '/clients', builder: (_, __) => const SizedBox()),
    GoRoute(path: '/contracts', builder: (_, __) => const SizedBox()),
    GoRoute(path: '/settings', builder: (_, __) => const SizedBox()),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: RepaintBoundary(
      key: key,
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  ));
  // Decode the artwork before the first frame is judged.
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final name in [
      'home',
      'vehicles',
      'vehicles_body',
      'settings',
      'body'
    ]) {
      await precacheImage(AssetImage('assets/backgrounds/bg_$name.webp'), ctx);
    }
  });
  return key;
}

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

void main() {
  late Uint8List photo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    photo = (await rootBundle.load('assets/backgrounds/bg_splash.webp'))
        .buffer
        .asUint8List();
  });

  testWidgets('Vehicles page: hero, then it collapses as you scroll',
      (tester) async {
    final vehicles = _vehicles(photo);
    final key = await _pumpApp(
      tester,
      screen: const VehiclesListScreen(),
      overrides: [
        vehiclesProvider.overrideWith(() => _FakeVehicles(vehicles)),
        contractsProvider.overrideWith(() => _FakeContracts([_contract])),
      ],
    );
    await _frames(tester, 2.0);
    expect(tester.takeException(), isNull);
    await _shot(tester, key, 'vehicles_0_top');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -170));
    await _frames(tester, 0.6);
    expect(tester.takeException(), isNull);
    await _shot(tester, key, 'vehicles_1_half');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await _frames(tester, 0.8);
    expect(tester.takeException(), isNull);
    await _shot(tester, key, 'vehicles_2_collapsed');

    // A tap sends a ring and the glints gather.
    // Tap the gap beside the collapsed bar, clear of every card.
    await tester.tapAt(const Offset(348, 200));
    await _frames(tester, 0.7);
    await _shot(tester, key, 'vehicles_3_ping');
    await _frames(tester, 3);
    expect(tester.takeException(), isNull);

    // No results: the empty state must stay readable on the dark page.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
    await _frames(tester, 0.6);
    await tester.enterText(find.byType(TextField), 'zzz');
    await _frames(tester, 0.6);
    expect(find.text('Aucun véhicule trouvé.'), findsOneWidget);
    await _shot(tester, key, 'vehicles_4_empty');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard: living background, priorities and stats',
      (tester) async {
    final vehicles = _vehicles(photo);
    final key = await _pumpApp(
      tester,
      screen: const DashboardScreen(),
      overrides: [
        vehiclesProvider.overrideWith(() => _FakeVehicles(vehicles)),
        contractsProvider.overrideWith(() => _FakeContracts([_contract])),
        dashboardProvider.overrideWith(_FakeDashboard.new),
        companyNameProvider.overrideWith((ref) async => 'MRX-BAIZ'),
        lookupsProvider.overrideWith((ref) async => _lookups(vehicles)),
      ],
    );
    await _frames(tester, 2.2);
    expect(tester.takeException(), isNull);
    await _shot(tester, key, 'dashboard_0_top');

    await tester.drag(find.byType(ListView).first, const Offset(0, -520));
    await _frames(tester, 1.2);
    expect(tester.takeException(), isNull);
    await _shot(tester, key, 'dashboard_1_scrolled');
  });

  testWidgets('Settings-style page: hero dissolves into the artwork behind it',
      (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late AmbientController ambient;

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: _SettingsLike(onController: (c) => ambient = c),
      ),
    ));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(MaterialApp));
      for (final name in ['settings', 'body']) {
        await precacheImage(
            AssetImage('assets/backgrounds/bg_$name.webp'), ctx);
      }
    });
    await _frames(tester, 2.0);
    expect(tester.takeException(), isNull);
    await _shot(tester, key, 'settings_0_top');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
    await _frames(tester, 0.6);
    await _shot(tester, key, 'settings_1_half');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await _frames(tester, 1.0);
    await _shot(tester, key, 'settings_2_deep');
    expect(tester.takeException(), isNull);

    // The camera has travelled across the artwork.
    expect(ambient.scrollOffset, greaterThan(800));
  });

  testWidgets('Splash: artwork pushes in while the gold line travels',
      (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: const SplashView(),
      ),
    ));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(MaterialApp));
      await precacheImage(
          const AssetImage('assets/backgrounds/bg_splash.webp'), ctx);
    });
    await _frames(tester, 1.2);
    await _shot(tester, key, 'splash_0');
    await _frames(tester, 2.0);
    await _shot(tester, key, 'splash_1');
    expect(tester.takeException(), isNull);
    expect(find.text('CHARGEMENT'), findsOneWidget);
  });

  testWidgets('A plain list page keeps the artwork behind it while scrolling',
      (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('Clients')),
          body: BackdropPage(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 20,
              itemBuilder: (context, i) => Reveal(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: SizedBox(
                      height: 64,
                      child: Text('Client ${i + 1}',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(MaterialApp));
      await precacheImage(
          const AssetImage('assets/backgrounds/bg_body.webp'), ctx);
    });
    await _frames(tester, 1.5);
    await _shot(tester, key, 'list_0_top');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await _frames(tester, 1.0);
    await _shot(tester, key, 'list_1_scrolled');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Vehicle detail: maintenance section is collapsed, with a status badge, '
      'and opens on tap', (tester) async {
    final vehicles = _vehicles(photo);
    final key = await _pumpApp(
      tester,
      screen: const VehicleDetailScreen(vehicleId: 1),
      overrides: [
        vehiclesProvider.overrideWith(() => _FakeVehicles(vehicles)),
        contractsProvider.overrideWith(() => _FakeContracts([_contract])),
        lookupsProvider.overrideWith((ref) async => _lookups(vehicles)),
      ],
    );
    await _frames(tester, 1.5);
    expect(tester.takeException(), isNull);
    // The full breakdown must not be on screen yet — only the summary.
    expect(find.textContaining('Expire dans'), findsNothing);
    await _shot(tester, key, 'vehicle_detail_0_collapsed');

    // The section sits below the fold on a phone-height screen.
    await tester.dragUntilVisible(
      find.text('Entretien et documents légaux'),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await _frames(tester, 0.3);
    await tester.tap(find.text('Entretien et documents légaux'));
    await _frames(tester, 0.4);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Expire dans'), findsOneWidget);
    await _shot(tester, key, 'vehicle_detail_1_expanded');
  });
}

/// The same composition Settings uses (hero + backdrop + revealed cards),
/// without the plumbing that needs a database.
class _SettingsLike extends StatefulWidget {
  const _SettingsLike({required this.onController});
  final ValueChanged<AmbientController> onController;

  @override
  State<_SettingsLike> createState() => _SettingsLikeState();
}

class _SettingsLikeState extends State<_SettingsLike>
    with SingleTickerProviderStateMixin {
  late final AmbientController _ambient = AmbientController(vsync: this);

  @override
  void initState() {
    super.initState();
    widget.onController(_ambient);
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final expanded = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(240.0, 320.0)
        .toDouble();
    return Scaffold(
      body: AmbientListener(
        controller: _ambient,
        child: Stack(
          children: [
            Positioned.fill(
              child: AmbientImage(
                controller: _ambient,
                asset: 'assets/backgrounds/bg_body.webp',
                zoom: 1.0,
                panFrom: const Alignment(-0.6, 0),
                panTo: const Alignment(0.75, 0.1),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(
                  color: AppColors.background.withValues(alpha: 0.22)),
            ),
            CustomScrollView(slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: HeroHeaderDelegate(
                  asset: 'assets/backgrounds/bg_settings.webp',
                  title: 'Paramètres',
                  showTitle: false,
                  expanded: expanded,
                  collapsed: top + kToolbarHeight,
                  topPadding: top,
                  controller: _ambient,
                  startAlignment: const Alignment(0, -0.05),
                  endAlignment: const Alignment(-0.2, 0.95),
                  foreground: AppColors.textPrimary,
                  scrim: AppColors.background,
                  scrimStrength: 0,
                  fadeBottom: true,
                  leading: IconButton(
                      icon: const Icon(Icons.arrow_back), onPressed: () {}),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: AnimatedTitle(
                      eyebrow: 'Votre agence',
                      title: 'Paramètres',
                      subtitle: 'MRX-BAIZ'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                sliver: SliverList.builder(
                  itemCount: 14,
                  itemBuilder: (context, i) => Reveal(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: SizedBox(
                          height: 72,
                          child: Text('Section ${i + 1}',
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
            Positioned.fill(child: AmbientGlints(controller: _ambient)),
            Positioned(
              right: 2,
              top: 0,
              bottom: 0,
              child: Center(child: ScrollRail(controller: _ambient)),
            ),
          ],
        ),
      ),
    );
  }
}
