import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'ambient_controller.dart';

double _smooth(double v, double a, double b) {
  final x = ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();
  return x * x * (3 - 2 * x);
}

/// A photo header for the top of a scroll view. As you scroll, the camera pans
/// across the picture (from [startAlignment] to [endAlignment]) while it zooms
/// and dims, the title lifts away, and a normal app bar takes over. Pull it at
/// the top and it leans toward your finger.
class HeroHeaderDelegate extends SliverPersistentHeaderDelegate {
  HeroHeaderDelegate({
    required this.asset,
    required this.title,
    required this.expanded,
    required this.collapsed,
    required this.controller,
    required this.topPadding,
    this.eyebrow,
    this.subtitle,
    this.showTitle = true,
    this.fadeBottom = false,
    this.startAlignment = Alignment.topCenter,
    this.endAlignment = Alignment.bottomCenter,
    this.foreground = Colors.white,
    this.barColor = Colors.white,
    this.collapsedForeground = AppColors.textPrimary,
    this.scrim = const Color(0xFF05070D),
    this.scrimStrength = 0.62,
    this.leading,
    this.actions = const [],
  });

  final String asset;
  final String title;
  final String? eyebrow;
  final String? subtitle;

  /// Draws the title over the photo. Off when the picture already carries the
  /// branding and the title is shown below it instead.
  final bool showTitle;

  /// Dissolves the bottom of the photo into the page behind it instead of
  /// ending on a hard edge. For light photos over a backdrop.
  final bool fadeBottom;
  final double expanded;
  final double collapsed;
  final AmbientController controller;
  final double topPadding;
  final Alignment startAlignment;
  final Alignment endAlignment;

  /// Colour of the title and toolbar icons while the photo is showing.
  final Color foreground;

  /// The collapsed toolbar's background, and the colour of its title and icons.
  final Color barColor;
  final Color collapsedForeground;
  final Color scrim;
  final double scrimStrength;
  final Widget? leading;
  final List<Widget> actions;

  @override
  double get maxExtent => expanded;

  @override
  double get minExtent => collapsed;

  @override
  bool shouldRebuild(covariant HeroHeaderDelegate old) =>
      old.asset != asset ||
      old.title != title ||
      old.eyebrow != eyebrow ||
      old.subtitle != subtitle ||
      old.showTitle != showTitle ||
      old.fadeBottom != fadeBottom ||
      old.expanded != expanded ||
      old.collapsed != collapsed ||
      old.topPadding != topPadding ||
      old.foreground != foreground ||
      old.barColor != barColor ||
      old.collapsedForeground != collapsedForeground ||
      old.scrim != scrim;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = math.max(1.0, expanded - collapsed);
    final t = (shrinkOffset / range).clamp(0.0, 1.0).toDouble();
    final pan = Curves.easeInOut.transform(t);

    // Tell the glints how much of the hero is left and how visible it is.
    controller
      ..clipHeight = math.max(collapsed, expanded - shrinkOffset)
      ..visibility = 1 - _smooth(t, 0.5, 0.95);

    final barIn = _smooth(t, 0.62, 0.95);
    final iconColor =
        Color.lerp(foreground, collapsedForeground, _smooth(t, 0.5, 0.9))!;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The photograph and its scrim, optionally dissolving at the bottom.
          _maybeFade(
            enabled: fadeBottom,
            t: t,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: controller,
                  child: RepaintBoundary(
                    child: Image.asset(
                      asset,
                      fit: BoxFit.cover,
                      alignment:
                          Alignment.lerp(startAlignment, endAlignment, pan)!,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    ),
                  ),
                  builder: (context, child) {
                    final still = controller.reduceMotion;
                    return Transform.translate(
                      offset: Offset(still ? 0 : controller.tilt.dx * -8,
                          shrinkOffset * 0.3),
                      child: Transform.scale(
                        scale: 1.06 +
                            0.12 * pan +
                            (still ? 0 : controller.boost * 0.005),
                        child: child,
                      ),
                    );
                  },
                ),
                // Dims as it collapses, and darkens the bottom for the title.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scrim.withValues(alpha: 0.16 + 0.3 * t),
                        scrim.withValues(alpha: 0.02),
                        scrim.withValues(
                            alpha: scrimStrength * (0.55 + 0.45 * t)),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Title block, lifting away as the header collapses.
          if (showTitle)
            Positioned(
              left: 20,
              right: 20,
              bottom: 22,
              child: Opacity(
                opacity: 1 - _smooth(t, 0, 0.55),
                child: Transform.translate(
                  offset: Offset(0, -shrinkOffset * 0.25),
                  child: AnimatedTitle(
                    title: title,
                    eyebrow: eyebrow,
                    subtitle: subtitle,
                    color: foreground,
                  ),
                ),
              ),
            ),
          // The collapsed toolbar fades in over the photo.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: collapsed,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: barIn),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.55 * barIn),
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: IconTheme(
                  data: IconThemeData(color: iconColor),
                  child: Row(
                    children: [
                      if (leading != null)
                        leading!
                      else
                        const SizedBox(width: 16),
                      Expanded(
                        child: Opacity(
                          opacity: _smooth(t, 0.75, 1),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: collapsedForeground,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _maybeFade({
  required bool enabled,
  required double t,
  required Widget child,
}) {
  if (!enabled) return child;
  // The soft edge shrinks as the header collapses, so the bar stays solid.
  final edge = 0.3 * (1 - t);
  return ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Colors.white, Colors.white, Colors.transparent],
      stops: [0, 1 - edge, 1],
    ).createShader(rect),
    child: child,
  );
}

/// Title, eyebrow and a gold hairline that draws itself in when it first
/// appears.
class AnimatedTitle extends StatefulWidget {
  const AnimatedTitle({
    super.key,
    required this.title,
    this.color = AppColors.textPrimary,
    this.eyebrow,
    this.subtitle,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Color color;

  @override
  State<AnimatedTitle> createState() => AnimatedTitleState();
}

class AnimatedTitleState extends State<AnimatedTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _step(double a, double b) => CurvedAnimation(
        parent: _controller,
        curve: Interval(a, b, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eyebrow = _step(0.0, 0.5);
    final title = _step(0.12, 0.65);
    final line = _step(0.3, 0.85);
    final subtitle = _step(0.4, 1.0);

    Widget lift(Animation<double> a, Widget child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.35), end: Offset.zero)
                .animate(a),
            child: child,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.eyebrow != null)
          lift(
            eyebrow,
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                widget.eyebrow!.toUpperCase(),
                style: TextStyle(
                  color: widget.color.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        lift(
          title,
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: widget.color,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: line,
          builder: (context, _) => Container(
            width: 64 * line.value,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.goldLight,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        if (widget.subtitle != null)
          lift(
            subtitle,
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                widget.subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.color.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
