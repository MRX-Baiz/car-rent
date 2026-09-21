import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// One drifting spark of light.
///
/// [depth] is the parallax layer: near glints (1.0) are larger, brighter and
/// travel further as the page scrolls than far ones (0.3), which is what makes
/// the field read as having depth rather than as flat confetti.
class Glint {
  Glint({
    required this.x,
    required this.y,
    required this.depth,
    required this.size,
    required this.phase,
    required this.twinkle,
    required this.spin,
    required this.driftX,
    required this.driftY,
    required this.orbitRadius,
    required this.orbitSpeed,
  });

  /// Base position as a fraction of the field, wrapped continuously.
  double x, y;
  final double depth;
  final double size;
  final double phase;
  final double twinkle;
  final double spin;
  final double driftX;
  final double driftY;
  final double orbitRadius;
  final double orbitSpeed;

  double rotation = 0;

  /// Displacement caused by a touch, in pixels, relaxed back to zero by a
  /// spring once the touch is over.
  double dx = 0, dy = 0;
  double vx = 0, vy = 0;

  bool gathered = false;
  double orbitAngle = 0;
}

/// An expanding sonar ring left by a tap.
class AmbientRing {
  AmbientRing({
    required this.center,
    required this.startedAt,
    required this.life,
    required this.maxRadius,
    this.strength = 1,
  });

  final Offset center;
  final double startedAt;
  final double life;
  final double maxRadius;
  final double strength;
}

/// Drives everything that moves in the background of a screen: a field of
/// glints that speeds up with the scroll, and a "ping" that a tap sends out,
/// which the glints answer by gathering around the touch and then scattering.
///
/// The motion model is borrowed from 34stud.io: scroll speed is smoothed into a
/// single boost value that scales ambient motion, and a tap emits a sonar ring
/// that nearby elements swarm to. Everything here is skipped under reduced
/// motion, and the ticker stops as soon as nothing is moving, so an idle screen
/// costs no battery.
class AmbientController extends ChangeNotifier {
  AmbientController({
    required TickerProvider vsync,
    int glintCount = 24,
    int seed = 34,
    this.reduceMotion = false,
  }) : glints = _generate(glintCount, seed) {
    _ticker = vsync.createTicker(_onTick);
  }

  final List<Glint> glints;
  final List<AmbientRing> rings = [];
  late final Ticker _ticker;

  /// Set by whoever owns the controller from MediaQuery.disableAnimations.
  bool reduceMotion;

  /// Size of the coordinate space pointer events and painters share.
  Size size = Size.zero;

  // Scroll -----------------------------------------------------------------
  double scrollOffset = 0;
  double scrollProgress = 0;
  double _scrollVelocity = 0;
  double _lastPixels = 0;
  bool _hasLastPixels = false;
  final Stopwatch _scrollWatch = Stopwatch();

  /// Smoothed 0..2.6 measure of how fast the page is being scrolled.
  double boost = 0;

  /// 0..1: how visible the scroll rail should be right now.
  double railOpacity = 0;

  // Touch ------------------------------------------------------------------
  Offset? pointer;
  bool pressed = false;

  /// 0..1 soft light under the finger.
  double glow = 0;

  /// Pointer offset from the centre, -1..1 on each axis, smoothed.
  Offset tilt = Offset.zero;
  Offset _tiltTarget = Offset.zero;

  Offset? _downAt;
  bool _dragged = false;
  int? _pointerId;
  final Stopwatch _touchWatch = Stopwatch();

  /// The active ping, if any: where it is and how long it has been running.
  Offset? pingCenter;
  double _pingAge = 0;

  // Simulation clock -------------------------------------------------------
  double time = 0;

  /// 0..1 fade-in when the screen first appears.
  double intro = 0;
  double _awake = 0;
  Duration _last = Duration.zero;

  /// How far the hero (if any) currently extends from the top, so glints can be
  /// confined to it. Null means the whole field is visible.
  double? clipHeight;

  /// 0..1 multiplier applied to glint opacity (e.g. fade out as a hero
  /// collapses).
  double visibility = 1;

  static const double _tapSlop = 14;
  static const double _pingMinSeconds = 1.8;

  // Input ------------------------------------------------------------------

  void scrolled(double pixels, double maxExtent) {
    scrollOffset = pixels;
    scrollProgress =
        maxExtent <= 0 ? 0 : (pixels / maxExtent).clamp(0.0, 1.0).toDouble();
    if (_hasLastPixels) {
      final ms = _scrollWatch.elapsedMicroseconds / 1000000;
      if (ms > 0.001) {
        final v = (pixels - _lastPixels) / ms;
        _scrollVelocity += (v - _scrollVelocity) * 0.5;
      }
    }
    _lastPixels = pixels;
    _hasLastPixels = true;
    _scrollWatch
      ..reset()
      ..start();
    _wake(1.2);
    if (reduceMotion) notifyListeners();
  }

  void pointerDown(int id, Offset position) {
    if (_pointerId != null) return;
    _pointerId = id;
    pressed = true;
    pointer = position;
    _downAt = position;
    _dragged = false;
    _touchWatch
      ..reset()
      ..start();
    _updateTilt(position);
    _wake(1.0);
  }

  void pointerMove(int id, Offset position) {
    if (id != _pointerId) return;
    pointer = position;
    if (!_dragged && _downAt != null) {
      if ((position - _downAt!).distance > _tapSlop) _dragged = true;
    }
    if (pingCenter != null) pingCenter = position;
    _updateTilt(position);
    _wake(1.0);
  }

  void pointerUp(int id, Offset position) {
    if (id != _pointerId) return;
    final isTap = !_dragged && _touchWatch.elapsedMilliseconds < 400;
    pointer = position;
    pressed = false;
    _pointerId = null;
    _touchWatch.stop();
    _tiltTarget = Offset.zero;
    // A quick tap pings where the finger lifted, like a click on the site.
    if (isTap && pingCenter == null && _canPingAt(position)) {
      _startPing(position);
    }
    _wake(_pingMinSeconds + 1.5);
  }

  void pointerCancel(int id) {
    if (id != _pointerId) return;
    pressed = false;
    _pointerId = null;
    _tiltTarget = Offset.zero;
    _touchWatch.stop();
    _wake(0.8);
  }

  void _updateTilt(Offset p) {
    if (size.isEmpty) return;
    final c = size.center(Offset.zero);
    _tiltTarget = Offset(
      ((p.dx - c.dx) / c.dx).clamp(-1.0, 1.0).toDouble(),
      ((p.dy - c.dy) / c.dy).clamp(-1.0, 1.0).toDouble(),
    );
  }

  // Ping -------------------------------------------------------------------

  /// When glints are confined to a hero, a ping outside it would send them
  /// flying out of view, so only touches inside it count.
  bool _canPingAt(Offset p) => clipHeight == null || p.dy <= clipHeight!;

  void _startPing(Offset at) {
    pingCenter = at;
    _pingAge = 0;
    rings.add(AmbientRing(
      center: at,
      startedAt: time,
      life: 1.0,
      maxRadius: 92,
    ));
    // Glints answer if they are close enough to hear it.
    final reach = math.max(220.0, size.shortestSide * 0.75);
    for (final g in glints) {
      final home = homeOf(g);
      final d = (home - at).distance;
      g.gathered = d < reach;
      if (g.gathered) {
        g.orbitAngle = math.atan2(home.dy - at.dy, home.dx - at.dx);
      }
    }
  }

  void _endPing() {
    final at = pingCenter;
    if (at == null) return;
    rings.add(AmbientRing(
      center: at,
      startedAt: time,
      life: 1.3,
      maxRadius: 170,
      strength: 0.7,
    ));
    // The school scatters: an outward burst, then the spring brings each
    // glint home.
    for (final g in glints) {
      if (!g.gathered) continue;
      final home = homeOf(g);
      final away = home + Offset(g.dx, g.dy) - at;
      final dir = away.distance < 1
          ? Offset(math.cos(g.orbitAngle), math.sin(g.orbitAngle))
          : away / away.distance;
      g.vx = dir.dx * (200 + 170 * g.depth);
      g.vy = dir.dy * (200 + 170 * g.depth);
      g.gathered = false;
    }
    pingCenter = null;
  }

  // Geometry ---------------------------------------------------------------

  /// Where a glint rests on screen before any touch displacement.
  Offset homeOf(Glint g) {
    final h = size.height;
    final w = size.width;
    const margin = 24.0;
    final span = h + margin * 2;
    final raw = g.y * h - scrollOffset * g.depth * 0.35;
    final wrapped = ((raw % span) + span) % span - margin;
    return Offset(g.x * w + tilt.dx * -7 * g.depth, wrapped);
  }

  // Loop -------------------------------------------------------------------

  void _wake(double seconds) {
    _awake = math.max(_awake, seconds);
    if (reduceMotion || _ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  /// Starts the entrance drift. Called once the size is known.
  void start() {
    if (reduceMotion) {
      intro = 1;
      notifyListeners();
      return;
    }
    _wake(2.8);
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1000000).clamp(0.0, 0.05);
    _last = elapsed;
    step(dt.toDouble());
    notifyListeners();
    if (isSettled) _ticker.stop();
  }

  /// One simulation step. Public so tests can drive it without a ticker.
  @visibleForTesting
  void step(double dt) {
    time += dt;
    _awake = math.max(0, _awake - dt);
    intro = math.min(1, intro + dt / 1.1);

    // Scroll energy: the lerp toward |v| / 550 is the same idea the site uses,
    // made frame-rate independent. Velocity itself decays when no scroll
    // events arrive, so boost falls back to zero once the finger lifts.
    final target = (_scrollVelocity.abs() / 550).clamp(0.0, 2.6).toDouble();
    boost += (target - boost) * (1 - math.exp(-dt / 0.14));
    _scrollVelocity *= math.exp(-dt / 0.12);
    final railTarget = _scrollVelocity.abs() > 30 ? 1.0 : 0.0;
    railOpacity += (railTarget - railOpacity) *
        (1 - math.exp(-dt / (railTarget > 0 ? 0.08 : 0.7)));

    glow += ((pressed ? 1.0 : 0.0) - glow) *
        (1 - math.exp(-dt / (pressed ? 0.08 : 0.4)));
    tilt += (_tiltTarget - tilt) * (1 - math.exp(-dt / 0.2));

    rings.removeWhere((r) => time - r.startedAt > r.life);

    // A finger held still for a moment pings too.
    if (pressed &&
        !_dragged &&
        pingCenter == null &&
        _touchWatch.elapsedMilliseconds > 220 &&
        pointer != null &&
        _canPingAt(pointer!)) {
      _startPing(pointer!);
    }
    if (pingCenter != null) {
      _pingAge += dt;
      if (!pressed && _pingAge >= _pingMinSeconds) _endPing();
    }

    final speed = 1 + boost * 1.6;
    for (final g in glints) {
      g.x = _wrap01(g.x + g.driftX * dt * speed);
      g.y = _wrap01(g.y - g.driftY * dt * speed);
      g.rotation += g.spin * dt * (1 + boost * 0.9);

      if (g.gathered && pingCenter != null) {
        g.orbitAngle += g.orbitSpeed * dt;
        final home = homeOf(g);
        final want = pingCenter! +
            Offset(math.cos(g.orbitAngle), math.sin(g.orbitAngle)) *
                g.orbitRadius -
            home;
        final k = 1 - math.exp(-dt / 0.16);
        g.dx += (want.dx - g.dx) * k;
        g.dy += (want.dy - g.dy) * k;
        g.vx = 0;
        g.vy = 0;
      } else {
        // Damped spring back to rest, with any burst velocity still in it.
        const stiffness = 7.0;
        const damping = 3.2;
        g.vx += (-stiffness * g.dx - damping * g.vx) * dt;
        g.vy += (-stiffness * g.dy - damping * g.vy) * dt;
        g.dx += g.vx * dt;
        g.dy += g.vy * dt;
      }
    }
  }

  /// True when nothing on screen is moving, so the ticker can rest.
  @visibleForTesting
  bool get isSettled {
    if (_awake > 0 || pressed || pingCenter != null || rings.isNotEmpty) {
      return false;
    }
    if (boost > 0.02 || railOpacity > 0.01 || glow > 0.01) return false;
    if (_scrollVelocity.abs() > 1) return false;
    if (tilt.distance > 0.002 || intro < 1) return false;
    for (final g in glints) {
      if (g.dx.abs() > 0.3 || g.dy.abs() > 0.3) return false;
      if (g.vx.abs() > 1 || g.vy.abs() > 1) return false;
    }
    return true;
  }

  bool get isTicking => _ticker.isActive;

  static double _wrap01(double v) => v - v.floorToDouble();

  static List<Glint> _generate(int count, int seed) {
    final rng = math.Random(seed);
    return List.generate(count, (i) {
      // Bias toward far glints so a few near ones stand out.
      final depth = 0.3 + math.pow(rng.nextDouble(), 1.4) * 0.7;
      return Glint(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        depth: depth,
        size: 3.5 + depth * 9,
        phase: rng.nextDouble() * math.pi * 2,
        twinkle: 1.2 + rng.nextDouble() * 2.2,
        spin: (rng.nextDouble() - 0.5) * 0.9,
        driftX: (rng.nextDouble() - 0.5) * 0.008,
        driftY: 0.006 + rng.nextDouble() * 0.014 * depth,
        orbitRadius: 30 + rng.nextDouble() * 70,
        orbitSpeed: (0.9 + rng.nextDouble() * 1.4) * (rng.nextBool() ? 1 : -1),
      )..rotation = rng.nextDouble() * math.pi;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
