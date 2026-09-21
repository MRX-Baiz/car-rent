import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// The one card surface used across the app: white, softly rounded, no border.
/// [accent] adds a coloured edge for cards that need to stand out (late
/// rentals, expired documents) without recolouring their whole content.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.accent,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? accent;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final accent = widget.accent;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(16);
    return Padding(
      padding: widget.margin,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onHighlightChanged:
                  onTap == null ? null : (v) => setState(() => _pressed = v),
              child: Stack(
                children: [
                  Padding(padding: widget.padding, child: widget.child),
                  if (accent != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 5,
                      child: ColoredBox(color: accent),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
