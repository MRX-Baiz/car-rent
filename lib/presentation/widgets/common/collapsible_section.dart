import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'app_card.dart';
import 'detail_row.dart';

/// A header that opens into [children] when tapped, instead of showing
/// everything at once. [badge] stays visible even collapsed — typically a
/// [StatusChip] — so a summary ("2 à traiter", "À jour") is readable without
/// opening the section.
///
/// Collapsed by default ([initiallyExpanded] = false): the screens that use
/// this were showing a full, always-open list of details that pushed
/// everything else down the page, which is the opposite of "easy to scan."
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.badge,
    this.initiallyExpanded = false,
    this.wrapInCard = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Shown next to the chevron, collapsed or not.
  final Widget? badge;
  final bool initiallyExpanded;

  /// False when the caller already provides the surrounding card (e.g. a
  /// disclosure nested inside another section's card) and only the
  /// header/toggle is needed, not a second border.
  final bool wrapInCard;

  /// Rendered as a [DetailList] when expanded.
  final List<Widget> children;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final hPad = widget.wrapInCard ? 16.0 : 0.0;

    final header = InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 14),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: theme.textTheme.titleSmall),
                  if (widget.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.badge != null) ...[
              const SizedBox(width: 8),
              widget.badge!,
            ],
            const SizedBox(width: 4),
            reduceMotion
                ? Transform.rotate(
                    angle: _expanded ? 3.14159 : 0,
                    child: const Icon(Icons.expand_more,
                        color: AppColors.textSecondary),
                  )
                : AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more,
                        color: AppColors.textSecondary),
                  ),
          ],
        ),
      ),
    );

    final expandedContent = !_expanded
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
            child: DetailList(children: widget.children),
          );
    // AnimatedSize keeps an internal AnimationController even at
    // Duration.zero, and that controller mutating layout state from inside
    // its own layout pass is a real Flutter quirk (not just a style choice)
    // — so reduced motion skips the animated wrapper entirely rather than
    // just zeroing its duration.
    final body = reduceMotion
        ? expandedContent
        : AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expandedContent,
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, body],
    );

    if (!widget.wrapInCard) return content;
    return AppCard(padding: EdgeInsets.zero, child: content);
  }
}
