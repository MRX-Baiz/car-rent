import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/navigation/tab_back_button_dispatcher.dart';
import 'core/notifications/notification_service.dart';
import 'data/models/client_model.dart';
import 'data/models/vehicle_model.dart';
import 'data/models/contract_model.dart';
import 'domain/entities/reservation.dart';
import 'presentation/screens/contracts/contract_detail_screen.dart';
import 'presentation/screens/contracts/contract_edit_screen.dart';
import 'presentation/screens/contracts/contract_form_screen.dart';
import 'presentation/screens/contracts/contracts_list_screen.dart';
import 'presentation/screens/contracts/inspection_form_screen.dart';
import 'presentation/screens/reservations/availability_calendar_screen.dart';
import 'presentation/screens/clients/client_detail_screen.dart';
import 'presentation/screens/clients/client_form_screen.dart';
import 'presentation/screens/clients/clients_list_screen.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/app_settings_provider.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/dashboard/today_operations_screen.dart';
import 'presentation/screens/license/license_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/lock/lock_screen.dart';
import 'presentation/screens/lock/pin_recovery_screen.dart';
import 'presentation/screens/lock/pin_setup_screen.dart';
import 'presentation/screens/vehicles/vehicle_detail_screen.dart';
import 'presentation/screens/vehicles/vehicle_form_screen.dart';
import 'presentation/screens/vehicles/vehicle_photos_screen.dart';
import 'presentation/screens/vehicles/vehicle_profitability_screen.dart';
import 'presentation/screens/vehicles/vehicles_list_screen.dart';
import 'presentation/screens/chauffeurs/chauffeurs_screen.dart';
import 'presentation/screens/assistant/assistant_model_screen.dart';
import 'presentation/screens/assistant/assistant_screen.dart';
import 'data/models/chauffeur_model.dart';

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
    // /lock/recovery lives under the lock screen on purpose: someone who has
    // forgotten their PIN must be able to reach it while still locked out.
    case LockStatus.locked:
      return path.startsWith('/lock') ? null : '/lock';
    case LockStatus.unlocked:
      return path.startsWith('/lock') || path == '/pin-setup'
          ? '/dashboard'
          : null;
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
      path: '/operations',
      builder: (context, state) => const TodayOperationsScreen(),
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
          // Listed before ':id' so this static segment isn't swallowed by
          // the parameterized vehicle-detail route below.
          path: 'profitability',
          builder: (context, state) => const VehicleProfitabilityScreen(),
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
        GoRoute(
            path: ':id/photos',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return id == null
                  ? const SplashScreen()
                  : VehiclePhotosScreen(vehicleId: id);
            }),
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
      path: '/availability',
      builder: (context, state) => const AvailabilityCalendarScreen(),
    ),
    GoRoute(
      path: '/contracts',
      builder: (context, state) => const ContractsListScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) {
            final extra = state.extra;
            return ContractFormScreen(
              initialVehicleId: extra is int ? extra : null,
              reservation: extra is Reservation ? extra : null,
            );
          },
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
          routes: [
            GoRoute(
                path: 'inspection/:type',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  final type = state.pathParameters['type'];
                  if (id == null || (type != 'departure' && type != 'return')) {
                    return const SplashScreen();
                  }
                  return InspectionFormScreen(contractId: id, type: type!);
                }),
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '');
                final contract = state.extra as ContractModel?;
                if (id == null || contract == null) {
                  return const SplashScreen();
                }
                return ContractEditScreen(contract: contract);
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/assistant',
      builder: (context, state) => const AssistantScreen(),
      routes: [
        GoRoute(
          path: 'model',
          builder: (context, state) => const AssistantModelScreen(),
        ),
      ],
    ),
    GoRoute(
        path: '/chauffeurs',
        builder: (context, state) => const ChauffeursScreen(),
        routes: [
          GoRoute(
              path: 'form',
              builder: (context, state) =>
                  ChauffeurFormScreen(value: state.extra as ChauffeurModel?)),
        ]),
    GoRoute(
      path: '/lock',
      builder: (context, state) => const LockScreen(),
      routes: [
        GoRoute(
          path: 'recovery',
          builder: (context, state) => const PinRecoveryScreen(),
        ),
      ],
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

class _CarRentAppState extends ConsumerState<CarRentApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pendingNotificationRoute.addListener(_openPendingNotification);
    // Also on unlock: a tap that arrived while locked has to wait for the PIN,
    // and nothing else would wake it afterwards.
    lockSignal.addListener(_openPendingNotification);
  }

  @override
  void dispose() {
    lockSignal.removeListener(_openPendingNotification);
    pendingNotificationRoute.removeListener(_openPendingNotification);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A notification tap cannot navigate on its own: with the app locked the
  /// guard would bounce it to /lock and the destination would be lost. The
  /// route is parked until the app is unlocked, then replayed.
  void _openPendingNotification() {
    final route = pendingNotificationRoute.value;
    if (route == null) return;
    if (lockSignal.value != LockStatus.unlocked) return;

    pendingNotificationRoute.value = null;
    _router.go(route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-lock is driven from here rather than from `detached`, which Android
    // routinely never delivers — the previous "log out on exit" hung off that
    // callback and so fired more or less at random.
    final auth = ref.read(authProvider.notifier);
    final notifications = NotificationService.instance;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        auth.noteBackgrounded();
        notifications.appInForeground = false;
        // Checked on the way out, not on the way in. Running this on resume
        // meant tapping the overdue notification brought the app up, which
        // immediately posted another one.
        notifications.notifyLateVehicles();
      case AppLifecycleState.resumed:
        auth.noteResumed();
        notifications.appInForeground = true;
        // The dashboard already shows what is overdue, so clear the summary
        // rather than leave it sitting in the shade.
        notifications.dismissLateDigest();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appLanguageProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CarRent Manager',
      theme: buildAppTheme(),
      locale: language.locale,
      supportedLocales:
          AppLanguage.values.map((language) => language.locale).toList(),
      localizationsDelegates: const [
        AppMessages.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Spelled out instead of routerConfig: passing the config wins over
      // backButtonDispatcher, so the custom dispatcher would be ignored.
      routeInformationProvider: _router.routeInformationProvider,
      routeInformationParser: _router.routeInformationParser,
      routerDelegate: _router.routerDelegate,
      backButtonDispatcher: _backButtonDispatcher,
    );
  }
}
