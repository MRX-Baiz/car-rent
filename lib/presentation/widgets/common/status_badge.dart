import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'status_chip.dart';

/// Badge for the domain statuses stored in the database (vehicle, contract,
/// chauffeur). Free-form states go through [StatusChip] directly.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
  });

  final String text;

  static const _tones = {
    'available': AppTone.success,
    'rented': AppTone.warning,
    'maintenance': AppTone.danger,
    'late': AppTone.danger,
    'active': AppTone.info,
    'completed': AppTone.neutral,
    'assigned': AppTone.warning,
  };

  static const _labels = {
    'available': 'Disponible',
    'rented': 'Loué',
    'maintenance': 'Maintenance',
    'late': 'En retard',
    'active': 'En cours',
    'completed': 'Terminé',
    'assigned': 'Occupé',
  };

  static const _icons = {
    'available': Icons.check_circle_outline,
    'rented': Icons.key_outlined,
    'maintenance': Icons.build_outlined,
    'late': Icons.schedule,
    'active': Icons.play_circle_outline,
    'completed': Icons.task_alt,
    'assigned': Icons.do_not_disturb_on_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: _labels[text] ?? text,
      tone: _tones[text] ?? AppTone.neutral,
      icon: _icons[text],
    );
  }
}
