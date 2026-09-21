import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'ambient_controller.dart';
import 'ambient_widgets.dart';

/// Puts the brand artwork behind a page so it never falls back to a flat
/// colour while you scroll.
///
/// The wide picture is much wider than a phone, so the camera slides across it
/// as you scroll (gold waves, then the logo, then the tagline). A light veil
/// keeps text readable, and gold glints drift behind the content.
class BackdropPage extends StatefulWidget {
  const BackdropPage({
    super.key,
    required this.child,
    this.asset = 'assets/backgrounds/bg_body.webp',
    this.glints = true,
    this.veil = 0.22,
  });

  final Widget child;
  final String asset;
  final bool glints;

  /// 0..1 how much of the page colour is laid over the artwork.
  final double veil;

  @override
  State<BackdropPage> createState() => _BackdropPageState();
}

class _BackdropPageState extends State<BackdropPage>
    with SingleTickerProviderStateMixin {
  late final AmbientController _ambient =
      AmbientController(vsync: this, glintCount: 16);

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AmbientListener(
      controller: _ambient,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AmbientImage(
              controller: _ambient,
              asset: widget.asset,
              zoom: 1.0,
              panFrom: const Alignment(-0.6, 0),
              panTo: const Alignment(0.75, 0.1),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.background.withValues(alpha: widget.veil),
            ),
          ),
          if (widget.glints)
            Positioned.fill(child: AmbientGlints(controller: _ambient)),
          Positioned.fill(child: widget.child),
          Positioned(
            right: 2,
            top: 0,
            bottom: 0,
            child: Center(child: ScrollRail(controller: _ambient)),
          ),
        ],
      ),
    );
  }
}
