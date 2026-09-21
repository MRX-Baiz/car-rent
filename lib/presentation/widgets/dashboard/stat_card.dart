import 'package:flutter/material.dart';

import '../common/app_card.dart';
import '../motion/count_up.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
    this.countTo,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  /// When set, the number counts up to it instead of showing [value] as is.
  final int? countTo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.primary;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: cardColor, size: 22),
              ),
              const Spacer(),
              // Long values and large system fonts shrink rather than clip.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: countTo == null
                      ? Text(
                          value,
                          maxLines: 1,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cardColor,
                          ),
                        )
                      : CountUpText(
                          value: countTo!,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cardColor,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
