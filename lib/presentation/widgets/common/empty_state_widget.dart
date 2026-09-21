import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.onDark = false,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  /// A next step, so an empty list never ends in a dead end.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Light text and a gold accent, for pages with a dark background.
  final bool onDark;

  /// A smaller, top-aligned version for pages where the space left under a
  /// header is short, so the message is never pushed under a floating button.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final circle = compact ? 48.0 : 88.0;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: circle,
          height: circle,
          decoration: BoxDecoration(
              color: (onDark ? AppColors.goldLight : AppColors.primary)
                  .withValues(alpha: onDark ? 0.14 : 0.08),
              shape: BoxShape.circle),
          child: Icon(icon,
              size: compact ? 24 : 40,
              color: onDark ? AppColors.goldLight : AppColors.primary),
        ),
        SizedBox(height: compact ? 8 : 16),
        Text(
          title,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: onDark ? Colors.white : null),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          SizedBox(height: compact ? 2 : 8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: onDark ? Colors.white70 : AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        if (actionLabel != null) ...[
          SizedBox(height: compact ? 14 : 20),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    if (compact) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 4, 32, 12),
          child: content,
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: content,
      ),
    );
  }
}
