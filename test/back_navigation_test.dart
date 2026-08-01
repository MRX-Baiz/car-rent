import 'package:car_rent_manager/core/navigation/tab_back_button_dispatcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as ft;
import 'package:go_router/go_router.dart';

/// Mirrors the tab layout in app.dart: flat top-level tabs reached with go(),
/// detail pages stacked with push().
GoRouter _buildRouter() => GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const Text('dashboard'),
        ),
        GoRoute(
          path: '/clients',
          builder: (_, __) => const Text('clients'),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) =>
                  Text('client ${state.pathParameters['id']}'),
            ),
          ],
        ),
        GoRoute(
          path: '/vehicles',
          builder: (_, __) => const Text('vehicles'),
        ),
        GoRoute(
          path: '/contracts',
          builder: (_, __) => const Text('contracts'),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const Text('settings'),
        ),
      ],
    );

void main() {
  late GoRouter router;
  late TabBackButtonDispatcher dispatcher;
  late List<String> platformCalls;

  setUp(() {
    router = _buildRouter();
    dispatcher = TabBackButtonDispatcher(
      router,
      tabRoots: const {'/vehicles', '/clients', '/contracts', '/settings'},
      home: '/dashboard',
    );
    platformCalls = <String>[];
    // SystemNavigator.pop on this channel is the app actually closing.
    ft.TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    ft.TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    router.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationProvider: router.routeInformationProvider,
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        backButtonDispatcher: dispatcher,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Delivers a hardware back press the way the platform channel does.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  bool appClosed() => platformCalls.contains('SystemNavigator.pop');

  testWidgets('back on a bare tab goes to the dashboard, not out of the app',
      (tester) async {
    await pumpApp(tester);

    for (final tab in ['/clients', '/vehicles', '/contracts', '/settings']) {
      router.go(tab);
      await tester.pumpAndSettle();
      expect(find.text(tab.substring(1)), findsOneWidget,
          reason: 'precondition: $tab is showing');

      await pressBack(tester);

      expect(find.text('dashboard'), findsOneWidget,
          reason: 'back from $tab should land on the dashboard');
      expect(appClosed(), isFalse,
          reason: 'back from $tab must not close the app');
    }
  });

  testWidgets('back on a pushed detail page still pops normally',
      (tester) async {
    await pumpApp(tester);
    router.go('/clients');
    await tester.pumpAndSettle();
    router.push('/clients/7');
    await tester.pumpAndSettle();
    expect(find.text('client 7'), findsOneWidget);

    await pressBack(tester);

    expect(find.text('clients'), findsOneWidget,
        reason: 'detail page should pop back to the list, not jump home');
    expect(appClosed(), isFalse);
  });

  testWidgets('back on the dashboard exits, as Android expects',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('dashboard'), findsOneWidget);

    await pressBack(tester);

    expect(appClosed(), isTrue,
        reason: 'the dashboard is the root; back there closes the app');
  });

  // Regression guard: a GoRoute.onExit returning false to keep the app alive
  // also vetoes ordinary go() calls, which froze tab switching entirely.
  testWidgets('switching between tabs still works', (tester) async {
    await pumpApp(tester);
    router.go('/clients');
    await tester.pumpAndSettle();

    router.go('/vehicles');
    await tester.pumpAndSettle();
    expect(find.text('vehicles'), findsOneWidget);

    router.go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
  });
}
