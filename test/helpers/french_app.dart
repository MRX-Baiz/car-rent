import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';

/// A [MaterialApp] in the app's default language (French).
///
/// Screens render their copy through `AppText`, which resolves it from the
/// active locale. A bare `MaterialApp` defaults to English, so tests that look
/// for the French source strings would silently stop matching.
MaterialApp frenchApp({required Widget home, ThemeData? theme}) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: AppMessages.supportedLocales,
      localizationsDelegates: AppMessages.localizationsDelegates,
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: home,
    );
