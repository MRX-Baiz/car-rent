import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../../presentation/widgets/motion/page_transitions.dart';
import 'app_colors.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.cardBackground,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: const Color(0xFF94A3B8),
    outlineVariant: AppColors.outline,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  final textTheme = base.textTheme
      .apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      )
      .copyWith(
        titleLarge: base.textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
        titleMedium: base.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        titleSmall:
            base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 13),
        labelLarge:
            base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: AppColors.cardBackground,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: AppColors.cardBackground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: DepthPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(const Color(0xFFCBD5E1)),
      enabledBorder: border(const Color(0xFFCBD5E1)),
      focusedBorder: border(AppColors.primary, 2),
      errorBorder: border(AppTone.danger.color),
      focusedErrorBorder: border(AppTone.danger.color, 2),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.penny,
      foregroundColor: AppColors.onPenny,
      elevation: 3,
      extendedTextStyle: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onPenny),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      checkmarkColor: AppColors.primary,
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      // The colour must be explicit: a chip label style without one rendered
      // white, so unselected chips looked empty.
      labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.textPrimary),
      secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.12),
        selectedForegroundColor: AppColors.primary,
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 10,
      iconColor: AppColors.textSecondary,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      unselectedLabelStyle:
          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      dividerColor: AppColors.outline,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      height: 68,
      indicatorColor: AppColors.penny.withValues(alpha: 0.4),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.pennyDark
                : AppColors.textSecondary,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.pennyDark
                : AppColors.textSecondary,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.penny.withValues(alpha: 0.4),
      selectedIconTheme: const IconThemeData(color: AppColors.pennyDark),
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
      selectedLabelTextStyle: const TextStyle(
          color: AppColors.pennyDark, fontWeight: FontWeight.w800),
      unselectedLabelTextStyle: const TextStyle(
          color: AppColors.textSecondary, fontWeight: FontWeight.w600),
    ),
  );
}
