import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';

import '../../../core/constants/app_colors.dart';

/// Registration number in a plate-like frame: the identifier the operator
/// actually looks for on the forecourt.
class PlateBadge extends StatelessWidget {
  const PlateBadge(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.textPrimary, width: 1.2),
      ),
      child: AppText(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 0.6,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
