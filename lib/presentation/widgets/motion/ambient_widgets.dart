import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ambient_controller.dart';

/// Which surface the glints sit on, so their gold reads on it.
enum GlintTone { onLight, onDark }

/// Feeds a screen's pointer and scroll events to an [AmbientController].
///
/// It only observes: a [Listener] takes no part in the gesture arena, so taps
/// and scrolling underneath behave exactly as before.
class AmbientListener extends StatefulWidget {
  const AmbientListener({
    super.key,
    required this.controller,
    required this.child,
  });

  final AmbientController controller;
  final Widget child;

  @override
  State<AmbientListener> createState() => _AmbientListenerState();
}

class _AmbientListenerState extends State<AmbientListener> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return LayoutBuilder(builder: (context, constraints) {
      c.size = constraints.biggest;
      if (!_started) {
        _started = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
            c.scrolled(n.metrics.pixels, n.metrics.maxScrollExtent);
          }
          return false;
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => c.pointerDown(e.pointer, e.localPosition),
          onPointerMove: (e) => c.pointerMove(e.pointer, e.localPosition),
          onPointerUp: (e) => c.pointerUp(e.pointer, e.localPosition),
          onPointerCancel: (e) => c.pointerCancel(e.pointer),
          child: widget.child,
        ),
      );
    });
  }
}

/// A full-bleed background photo that moves with the page: it drifts as you
/// scroll, leans slightly toward your finger and swells a touch with scroll
/// speed. The drift saturates smoothly, so it never runs out of image.
///
/// Given [panFrom] and [panTo], the camera also travels across the picture as
/// you scroll, which is how a wide landscape image can live behind a portrait
/// phone screen: the page starts on one part of the artwork and slides toward
/// another. [panDistance] is the scroll length over which most of that travel
/// happens.
class AmbientImage extends StatelessWidget {
  const AmbientImage({
    super.key,
    required this.controller,
    required this.asset,
    this.alignment = Alignment.center,
    this.zoom = 1.1,
    this.panFrom,
    this.panTo,
    this.panDistance = 1800,
  });

  final AmbientController controller;
  final String asset;
  final Alignment alignment;
  final double zoom;
  final Alignment? panFrom;
  final Alignment? panTo;
  final double panDistance;

  static double _tanh(double x) {
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  Widget _image(Alignment at) => RepaintBoundary(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: at,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final panning = panFrom != null && panTo != null;
    return LayoutBuilder(builder: (context, constraints) {
      final maxShift = constraints.maxHeight * 0.04;
      final still = controller.reduceMotion;
      return ClipRect(
        child: AnimatedBuilder(
          animation: controller,
          // Without panning the picture is identical every frame, so it is
          // built once and only transformed.
          child: panning ? null : _image(alignment),
          builder: (context, child) {
            final shiftY = still
                ? 0.0
                : -maxShift * _tanh(controller.scrollOffset / (maxShift * 9));
            final shiftX = still ? 0.0 : controller.tilt.dx * -9;
            final scale = zoom + (still ? 0.0 : controller.boost * 0.006);
            final picture = child ??
                _image(Alignment.lerp(
                  panFrom,
                  panTo,
                  still
                      ? 0
                      : 1 - math.exp(-controller.scrollOffset / panDistance),
                )!);
            return Transform.translate(
              offset: Offset(shiftX, shiftY),
              child: Transform.scale(scale: scale, child: picture),
            );
          },
        ),
      );
    });
  }
}

/// The drifting glints, the light under the finger and the sonar rings.
class AmbientGlints extends StatelessWidget {
  const AmbientGlints({
    super.key,
    required this.controller,
    this.tone = GlintTone.onLight,
    this.confined = true,
  });

  final AmbientController controller;
  final GlintTone tone;

  /// When true the glints stay inside the hero and fade as it collapses. An
  /// unconfined layer covers the whole page, for use behind the content.
  final bool confined;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GlintPainter(controller, tone, confined),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GlintPainter extends CustomPainter {
  _GlintPainter(this.c, this.tone, this.confined) : super(repaint: c);

  final AmbientController c;
  final GlintTone tone;
  final bool confined;

  // A four-point sparkle with concave sides, built once at unit radius.
  static final Path _star = Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(0.11, -0.11, 1, 0)
    ..quadraticBezierTo(0.11, 0.11, 0, 1)
    ..quadraticBezierTo(-0.11, 0.11, -1, 0)
    ..quadraticBezierTo(-0.11, -0.11, 0, -1)
    ..close();

  Color get _core => tone == GlintTone.onDark
      ? const Color(0xFFFFE7AE)
      : const Color(0xFFC08F1F);
  Color get _halo => tone == GlintTone.onDark
      ? const Color(0xFFFFC65C)
      : const Color(0xFFE2B94A);

  @override
  void paint(Canvas canvas, Size size) {
    if (c.reduceMotion) return;
    canvas.save();
    final clip = confined ? c.clipHeight : null;
    if (clip != null) {
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, math.max(0, clip)));
    }

    final fade = c.intro * (confined ? c.visibility : 1.0);

    // Soft light that follows the finger.
    final p = c.pointer;
    if (p != null && c.glow > 0.01) {
      final paint = Paint();
      for (final layer in const [(120.0, 0.05), (78.0, 0.07), (40.0, 0.10)]) {
        paint.color = _halo.withValues(alpha: layer.$2 * c.glow * fade);
        canvas.drawCircle(p, layer.$1, paint);
      }
    }

    // Sonar rings.
    for (final r in c.rings) {
      final t = ((c.time - r.startedAt) / r.life).clamp(0.0, 1.0).toDouble();
      final radius = r.maxRadius * (1 - math.pow(1 - t, 3));
      final alpha = math.pow(1 - t, 1.4) * r.strength * fade;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = _core.withValues(alpha: 0.55 * alpha);
      canvas.drawCircle(r.center, radius, ring);
      ring.color = _core.withValues(alpha: 0.3 * alpha);
      canvas.drawCircle(r.center, radius * 0.66, ring);
      // Short bright arcs turning around the ring give it the radar feel.
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2
        ..color = _core.withValues(alpha: 0.75 * alpha);
      final rect = Rect.fromCircle(center: r.center, radius: radius * 1.08);
      for (var k = 0; k < 3; k++) {
        canvas.drawArc(rect, t * 2.6 + k * 2.094, 0.7, false, arc);
      }
    }

    // Glints, far to near so near ones sit on top.
    final w = size.width;
    final h = size.height;
    final body = Paint()..style = PaintingStyle.fill;
    for (final g in c.glints) {
      final pos = c.homeOf(g) + Offset(g.dx, g.dy);
      if (pos.dx < -30 || pos.dx > w + 30 || pos.dy < -30 || pos.dy > h + 30) {
        continue;
      }
      final twinkle = 0.62 + 0.38 * math.sin(c.time * g.twinkle + g.phase);
      final alpha =
          ((0.28 + 0.72 * g.depth) * twinkle * fade).clamp(0.0, 1.0).toDouble();
      if (alpha < 0.02) continue;
      final r = g.size * (1 + c.boost * 0.12);

      // Halo: three stacked translucent discs read as a soft glow without the
      // cost of a blur.
      body.color = _halo.withValues(alpha: 0.05 * alpha);
      canvas.drawCircle(pos, r * 2.4, body);
      body.color = _halo.withValues(alpha: 0.09 * alpha);
      canvas.drawCircle(pos, r * 1.6, body);
      body.color = _halo.withValues(alpha: 0.16 * alpha);
      canvas.drawCircle(pos, r * 0.95, body);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(g.rotation);
      canvas.scale(r);
      body.color = _core.withValues(alpha: alpha);
      canvas.drawPath(_star, body);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlintPainter old) =>
      old.tone != tone || old.c != c || old.confined != confined;
}

/// A slim gauge on the right edge that shows how far down the page you are.
/// It appears while you scroll and fades away when you stop, the way the depth
/// gauge on 34stud.io does.
class ScrollRail extends StatelessWidget {
  const ScrollRail({
    super.key,
    required this.controller,
    this.color = const Color(0xFFC08F1F),
    this.height = 132,
  });

  final AmbientController controller;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final opacity =
              controller.reduceMotion ? 0.0 : controller.railOpacity;
          if (opacity < 0.01) return const SizedBox.shrink();
          return Opacity(
            opacity: opacity * 0.9,
            child: CustomPaint(
              size: Size(14, height),
              painter: _RailPainter(controller.scrollProgress, color),
            ),
          );
        },
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width - 3;
    final line = Paint()
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.35);
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    const step = 11.0;
    var i = 0;
    for (var y = 0.0; y <= size.height; y += step, i++) {
      final long = i % 5 == 0;
      canvas.drawLine(Offset(x, y), Offset(x - (long ? 8 : 4), y), line);
    }
    final dotY = progress * size.height;
    canvas.drawCircle(
        Offset(x, dotY), 7, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawCircle(Offset(x, dotY), 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) =>
      old.progress != progress || old.color != color;
}
