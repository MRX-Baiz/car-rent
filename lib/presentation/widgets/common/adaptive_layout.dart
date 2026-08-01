import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    super.key,
    required this.child,
  });

  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/vehicles')) return 1;
    if (location.startsWith('/clients')) return 2;
    if (location.startsWith('/contracts')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/vehicles');
        break;
      case 2:
        context.go('/clients');
        break;
      case 3:
        context.go('/contracts');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final currentIndex = _indexForLocation(GoRouter.of(context).routeInformationProvider.value.uri.toString());

    // Hardware back for the tabs is handled by GoRoute.onExit in app.dart.
    // PopScope cannot be used here: when a tab is the only route, go_router's
    // popRoute() sees canPop() == false and never calls maybePop(), so a
    // PopScope in this subtree is never consulted.
    return _buildBody(context, isDesktop, currentIndex);
  }

  Widget _buildBody(BuildContext context, bool isDesktop, int currentIndex) {
    if (isDesktop) {
      return Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF2C2B28),
            selectedIndex: currentIndex,
            onDestinationSelected: (index) =>
                _onDestinationSelected(context, index),
            labelType: NavigationRailLabelType.all,
            indicatorColor: const Color(0xFFecf0ec).withValues(alpha: 0.2),
            unselectedIconTheme: const IconThemeData(color: Color(0xFFecf0ec)),
            selectedIconTheme: const IconThemeData(color: Color(0xFFecf0ec)),
            unselectedLabelTextStyle: const TextStyle(color: Color(0xFFecf0ec)),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFFecf0ec),
              fontWeight: FontWeight.bold,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.directions_car_outlined),
                selectedIcon: Icon(Icons.directions_car),
                label: Text('Véhicules'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Clients'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Contrats'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Paramètres'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      );
    } else {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: const Color(0xFF2C2B28),
            indicatorColor: const Color(0xFFecf0ec).withValues(alpha: 0.2),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              return const TextStyle(
                color: Color(0xFFecf0ec),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              );
            }),
            iconTheme: WidgetStateProperty.all(
              const IconThemeData(color: Color(0xFFecf0ec)),
            ),
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) =>
                _onDestinationSelected(context, index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_car_outlined),
                selectedIcon: Icon(Icons.directions_car),
                label: 'Véhicules',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Clients',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Contrats',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Paramètres',
              ),
            ],
          ),
        ),
      );
    }
  }
}

