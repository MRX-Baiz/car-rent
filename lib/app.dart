import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_theme.dart';
import 'core/navigation/tab_back_button_dispatcher.dart';
import 'data/models/client_model.dart';
import 'data/models/vehicle_model.dart';
import 'presentation/screens/contracts/contract_detail_screen.dart';
import 'presentation/screens/contracts/contract_form_screen.dart';
import 'presentation/screens/contracts/contracts_list_screen.dart';
import 'presentation/screens/clients/client_detail_screen.dart';
import 'presentation/screens/clients/client_form_screen.dart';
import 'presentation/screens/clients/clients_list_screen.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/license/license_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/lock/lock_screen.dart';
import 'presentation/screens/lock/pin_setup_screen.dart';
import 'presentation/screens/vehicles/vehicle_detail_screen.dart';
import 'presentation/screens/vehicles/vehicle_form_screen.dart';
import 'presentation/screens/vehicles/vehicles_list_screen.dart';

/// Reachable with the app locked: the splash decides where to go, and the
/// licence screen has to work before a PIN can exist.
const _unguarded = {'/splash', '/license'};

/// The single place that decides whether a screen may be shown. Without it the
/// lock would only be a suggestion, since any context.go() could step past it.
///
/// Kept pure — status and path in, destination out — so the rules can be tested
/// without building the app.
@visibleForTesting
String? lockRedirect(LockStatus status, String path) {
  if (_unguarded.contains(path)) {
    return null;
  }

  switch (status) {
    // Storage not read yet; the splash resolves it and routes on.
    case LockStatus.unknown:
      return '/splash';
    case LockStatus.needsSetup:
      return path == '/pin-setup' ? null : '/pin-setup';
    case LockStatus.locked:
      return path == '/lock' ? null : '/lock';
    case LockStatus.unlocked:
      return path == '/lock' || path == '/pin-setup' ? '/dashboard' : null;
  }
}

String? _lockGuard(BuildContext context, GoRouterState state) =>
    lockRedirect(lockSignal.value, state.matchedLocation);

final _router = GoRouter(
  initialLocation: '/splash',
  redirect: _lockGuard,
  // Locking mid-session has to move the app off whatever page is open.
  refreshListenable: lockSignal,
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/license',
      builder: (context, state) => const LicenseScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/vehicles',
      builder: (context, state) => const VehiclesListScreen(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const VehicleFormScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) {
              return const SplashScreen();
            }
            return VehicleDetailScreen(vehicleId: id);
          },
        ),
        GoRoute(
          path: ':id/edit',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            final vehicle = state.extra as VehicleModel?;
            if (id == null) {
              return const SplashScreen();
            }
            return VehicleFormScreen(vehicle: vehicle);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/clients',
      builder: (context, state) => const ClientsListScreen(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) {
            final extra = state.extra;
            final mode = extra is Map && extra['mode'] == 'scan'
                ? ClientFormMode.ocr
                : ClientFormMode.manual;
            return ClientFormScreen(initialMode: mode);
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) {
              return const SplashScreen();
            }
            return ClientDetailScreen(clientId: id);
          },
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '');
                final client = state.extra as ClientModel?;
                if (id == null || client == null) {
                  return const SplashScreen();
                }
                return ClientFormScreen(client: client);
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/contracts',
      builder: (context, state) => const ContractsListScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => const ContractFormScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) {
              return const SplashScreen();
            }
            return ContractDetailScreen(contractId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/lock',
      builder: (context, state) => const LockScreen(),
    ),
    GoRoute(
      path: '/pin-setup',
      builder: (context, state) => const PinSetupScreen(),
    ),
    // Changing the PIN sits under /settings so it stays behind the lock.
    GoRoute(
      path: '/settings/pin',
      builder: (context, state) => const PinSetupScreen(isChange: true),
    ),
  ],
);

/// Back from a bare tab lands on the dashboard rather than closing the app.
/// Built once: Router re-registers its callbacks whenever the instance changes.
final _backButtonDispatcher = TabBackButtonDispatcher(
  _router,
  tabRoots: const {'/vehicles', '/clients', '/contracts', '/settings'},
  home: '/dashboard',
);

class CarRentApp extends ConsumerStatefulWidget {
  const CarRentApp({super.key});

  @override
  ConsumerState<CarRentApp> createState() => _CarRentAppState();
}

class _CarRentAppState extends ConsumerState<CarRentApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-lock is driven from here rather than from `detached`, which Android
    // routinely never delivers — the previous "log out on exit" hung off that
    // callback and so fired more or less at random.
    final auth = ref.read(authProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        auth.noteBackgrounded();
      case AppLifecycleState.resumed:
        auth.noteResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CarRent Manager',
      theme: buildAppTheme(),
      // Spelled out instead of routerConfig: passing the config wins over
      // backButtonDispatcher, so the custom dispatcher would be ignored.
      routeInformationProvider: _router.routeInformationProvider,
      routeInformationParser: _router.routeInformationParser,
      routerDelegate: _router.routerDelegate,
      backButtonDispatcher: _backButtonDispatcher,
    );
  }
}

