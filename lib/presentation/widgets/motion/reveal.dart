import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slides a child up into place with a slight tilt that settles as it lands,
/// the way the quote cards on 34stud.io arrive.
///
/// It plays when the widget is first built, and lazy lists build their items
/// as they scroll into view, so cards animate in as you reach them. [index]
/// staggers neighbours by a few tens of milliseconds. Under reduced motion the
/// child is simply shown.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 26,
    this.tilt = 0.014,
    this.duration = const Duration(milliseconds: 520),
  });

  final Widget child;
  final int index;
  final double offset;

  /// Starting rotation in radians; alternates direction with [index].
  final double tilt;
  final Duration duration;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final delayMs = math.min(widget.index, 6) * 55;
    final total = widget.duration.inMilliseconds + delayMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    // The stagger is folded into one animation as a leading dead zone, which
    // avoids a Timer that could outlive the widget.
    _t = CurvedAnimation(
      parent: _controller,
      curve: Interval(delayMs / total, 1, curve: Curves.easeOutCubic),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final sign = widget.index.isEven ? 1.0 : -1.0;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final t = _t.value;
        if (t >= 1) return child!;
        return Opacity(
          opacity: t,
          child: Transform(
            alignment: Alignment.bottomLeft,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, (1 - t) * widget.offset, 0.0, 1.0)
              ..rotateZ((1 - t) * widget.tilt * sign),
            child: child,
          ),
        );
      },
    );
  }
}
