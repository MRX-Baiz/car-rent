import 'package:flutter/material.dart';

/// Screens rise gently into place while the one beneath recedes a little and
/// dims, so navigation reads as depth rather than a swap.
class DepthPageTransitionsBuilder extends PageTransitionsBuilder {
  const DepthPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 360);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 280);

  static final _ease = CurveTween(curve: Curves.easeInOutCubic);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final enter = animation.drive(_ease);
    final recede = secondaryAnimation.drive(_ease);
    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: enter.drive(
          Tween(begin: const Offset(0, 0.035), end: Offset.zero),
        ),
        child: FadeTransition(
          opacity: recede.drive(Tween(begin: 1.0, end: 0.7)),
          child: ScaleTransition(
            scale: recede.drive(Tween(begin: 1.0, end: 0.965)),
            child: child,
          ),
        ),
      ),
    );
  }
}
