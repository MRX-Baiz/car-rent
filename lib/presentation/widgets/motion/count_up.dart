import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';

/// A number that counts up from zero when it first appears, and counts from its
/// old value to the new one when it changes. Shown at once under reduced
/// motion.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.format,
    this.duration = const Duration(milliseconds: 900),
  });

  final num value;
  final TextStyle? style;
  final String Function(double value)? format;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? value.toDouble() : 0, end: value.toDouble()),
      duration: still ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => AppText(
        format != null ? format!(v) : v.round().toString(),
        maxLines: 1,
        style: style,
      ),
    );
  }
}
