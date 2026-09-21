import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// A tinted message with an optional action. Used for anything the operator
/// should not miss: late returns, expired documents, blocked permissions.
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.title,
    this.message,
    this.tone = AppTone.warning,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onTap,
  });

  final String title;
  final String? message;
  final AppTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: tone.soft,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon ?? tone.icon, color: tone.color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: tone.color, fontWeight: FontWeight.w800),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        message!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                    if (actionLabel != null) ...[
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: onAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: tone.color,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                        ),
                        child: Text(actionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: tone.color),
            ],
          ),
        ),
      ),
    );
  }
}
