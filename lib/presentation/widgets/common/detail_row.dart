import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Label above value, with a leading icon and an optional trailing widget
/// (usually a [StatusChip]). Built for scanning a detail card top to bottom.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trailing,
    this.onTap,
    this.mono = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: AppColors.textSecondary),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      value.isEmpty ? '—' : value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: mono ? 'monospace' : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(child: trailing!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A short list of [DetailRow]s separated by hairlines inside one card body.
class DetailList extends StatelessWidget {
  const DetailList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          children[i],
        ],
      ],
    );
  }
}

/// Icon + big value + small label tiles, two per row. Used for the key numbers
/// of a vehicle (mileage, fuel, gearbox...) that are read, not edited.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.items});
  final List<MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 10.0;
      final width = (constraints.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final item in items)
            SizedBox(width: width, child: _MetricTile(item: item)),
        ],
      );
    });
  }
}

class MetricItem {
  const MetricItem(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item});
  final MetricItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
