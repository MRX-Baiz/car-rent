import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.radius = 24});

  final String name;
  final double radius;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      foregroundColor: AppColors.primary,
      child: Text(
        _initials,
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w800),
      ),
    );
  }
}
