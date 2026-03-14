import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
  });

  final String text;

  Color _backgroundColor() {
    switch (text) {
      case 'available':
        return AppColors.statusAvailable.withOpacity(0.12);
      case 'rented':
        return AppColors.statusRented.withOpacity(0.12);
      case 'maintenance':
        return AppColors.statusMaintenance.withOpacity(0.12);
      case 'late':
        return AppColors.statusLate.withOpacity(0.12);
      case 'active':
        return AppColors.statusActive.withOpacity(0.12);
      case 'completed':
        return AppColors.statusCompleted.withOpacity(0.12);
      default:
        return Colors.grey.withOpacity(0.12);
    }
  }

  Color _textColor() {
    switch (text) {
      case 'available':
        return AppColors.statusAvailable;
      case 'rented':
        return AppColors.statusRented;
      case 'maintenance':
        return AppColors.statusMaintenance;
      case 'late':
        return AppColors.statusLate;
      case 'active':
        return AppColors.statusActive;
      case 'completed':
        return AppColors.statusCompleted;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor(),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _textColor(),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

