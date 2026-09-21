import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

String fuelTypeName(String value) =>
    const {
      'petrol': 'Essence',
      'diesel': 'Diesel',
      'hybrid': 'Hybride',
      'electric': 'Électrique',
      'lpg': 'GPL',
    }[value] ??
    value;

IconData fuelTypeIcon(String value) =>
    value == 'electric' ? Icons.electric_car_outlined : Icons.local_gas_station;

String transmissionName(String value) =>
    value == 'automatic' ? 'Automatique' : 'Manuelle';

String conditionName(String value) =>
    const {
      'good': 'Bon état',
      'check': 'À contrôler',
      'damaged': 'Endommagé',
    }[value] ??
    value;

AppTone conditionTone(String value) => switch (value) {
      'good' => AppTone.success,
      'check' => AppTone.warning,
      'damaged' => AppTone.danger,
      _ => AppTone.neutral,
    };

IconData conditionIcon(String value) => switch (value) {
      'good' => Icons.check_circle_outline,
      'check' => Icons.visibility_outlined,
      'damaged' => Icons.car_crash_outlined,
      _ => Icons.help_outline,
    };
