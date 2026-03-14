import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_theme.dart';
import 'data/models/vehicle_model.dart';
import 'presentation/screens/contracts/contract_detail_screen.dart';
import 'presentation/screens/contracts/contract_form_screen.dart';
import 'presentation/screens/contracts/contracts_list_screen.dart';
import 'presentation/screens/clients/client_detail_screen.dart';
import 'presentation/screens/clients/client_form_screen.dart';
import 'presentation/screens/clients/clients_list_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/license/license_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/vehicles/vehicle_detail_screen.dart';
import 'presentation/screens/vehicles/vehicle_form_screen.dart';
import 'presentation/screens/vehicles/vehicles_list_screen.dart';

final _router = GoRouter(
  initialLocation: '/splash',
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
  ],
);

class CarRentApp extends ConsumerWidget {
  const CarRentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CarRent Manager',
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}

