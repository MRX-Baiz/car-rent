import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2563EB); // Blue
  static const Color secondary = Color(0xFF0F172A); // Navy
  static const Color navy = Color(0xFF0F172A);

  /// Brand gold, from the logo. Used sparingly: hairlines, sparks, hero accents.
  static const Color gold = Color(0xFFC08F1F);
  static const Color goldLight = Color(0xFFF2D58A);

  /// Creamy copper ("penny"): the accent for the main call-to-action buttons and
  /// the bottom navigation. Dark [onPenny] text sits on it (7.8:1); use
  /// [pennyDark] for icons and labels drawn on white (5.4:1).
  static const Color penny = Color(0xFFD9A77F);
  static const Color onPenny = Color(0xFF2B1A0E);
  static const Color pennyDark = Color(0xFF9A5B2E);

  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color outline = Color(0xFFE2E8F0);

  static const Color statusAvailable = Color(0xFF4CAF50); // Green
  static const Color statusRented = Color(0xFFFF9800); // Orange
  static const Color statusMaintenance = Color(0xFFF44336); // Red

  static const Color statusLate = Color(0xFFD32F2F); // Dark red
  static const Color statusActive = Color(0xFF2196F3); // Blue
  static const Color statusCompleted = Color(0xFF9E9E9E); // Grey
}

/// The only five status colours the UI uses. Text colours are picked to reach
/// at least 4.5:1 on their own soft background so badges stay readable in
/// sunlight, which the older light-green/orange status colours did not.
enum AppTone { success, warning, danger, info, neutral }

extension AppToneColors on AppTone {
  Color get color => switch (this) {
        AppTone.success => const Color(0xFF15803D),
        AppTone.warning => const Color(0xFF9A5B00),
        AppTone.danger => const Color(0xFFDC2626),
        AppTone.info => const Color(0xFF2563EB),
        AppTone.neutral => AppColors.textSecondary,
      };

  Color get soft => switch (this) {
        AppTone.success => const Color(0xFFDCFCE7),
        AppTone.warning => const Color(0xFFFFF1D6),
        AppTone.danger => const Color(0xFFFEE2E2),
        AppTone.info => const Color(0xFFDBEAFE),
        AppTone.neutral => const Color(0xFFF1F5F9),
      };

  IconData get icon => switch (this) {
        AppTone.success => Icons.check_circle_outline,
        AppTone.warning => Icons.warning_amber_rounded,
        AppTone.danger => Icons.error_outline,
        AppTone.info => Icons.info_outline,
        AppTone.neutral => Icons.info_outline,
      };
}
