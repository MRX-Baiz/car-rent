import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Sends the hardware back button to the dashboard when a bottom-navigation
/// tab is showing on its own, instead of closing the app.
///
/// Why a dispatcher rather than the two obvious alternatives:
///
///  * `PopScope` is never consulted. [GoRouterDelegate.popRoute] discards the
///    navigator when `canPop()` is false, so `maybePop()` — the only thing that
///    runs `PopScope` callbacks — is skipped whenever a tab is the only route.
///
///  * [GoRoute.onExit] fires on *every* exit, not just back presses:
///    `setNewRoutePath` calls it for each leaving route on an ordinary `go()`.
///    Returning false to keep the app alive therefore vetoes tab-to-tab
///    navigation too, and navigating from inside the callback re-enters
///    `setNewRoutePath`, which loops until the app locks up.
///
/// The dispatcher sits above the router and sees the back press before it turns
/// into a pop, so neither problem applies.
class TabBackButtonDispatcher extends RootBackButtonDispatcher {
  TabBackButtonDispatcher(
    this._router, {
    required this.tabRoots,
    required this.home,
  });

  final GoRouter _router;

  /// Locations that should fall back to [home] instead of closing the app.
  final Set<String> tabRoots;

  /// Where a bare tab sends the user; back from here exits, as Android expects.
  final String home;

  @override
  Future<bool> didPopRoute() {
    final delegate = _router.routerDelegate;

    // Anything stacked on top — a detail page, a dialog, a bottom sheet — has
    // to pop normally, so only a bare tab reaches the redirect. Checking
    // canPop() first also sidesteps the fact that currentConfiguration.uri
    // ignores pushed (imperative) routes and would still read as the tab.
    if (!delegate.canPop() &&
        tabRoots.contains(delegate.currentConfiguration.uri.path)) {
      _router.go(home);
      return Future<bool>.value(true); // handled: do not close the app
    }

    return super.didPopRoute();
  }
}
