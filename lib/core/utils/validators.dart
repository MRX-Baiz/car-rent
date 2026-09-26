import 'package:flutter/widgets.dart';

import '../localization/app_localizations.dart';

/// Form and input validators used across the app.
class Validators {
  static String _text(BuildContext? context, String source) =>
      context == null ? source : context.tr(source);

  /// Non-empty string.
  static String? required(String? value,
      [String message = 'Ce champ est requis.', BuildContext? context]) {
    if (value == null || value.trim().isEmpty) return _text(context, message);
    return null;
  }

  /// Non-null, positive integer (e.g. year).
  static String? positiveInt(String? value,
      {int? min, int? max, BuildContext? context}) {
    if (value == null || value.trim().isEmpty) {
      return _text(context, 'Ce champ est requis.');
    }
    final n = int.tryParse(value.trim());
    if (n == null) return _text(context, 'Valeur numérique invalide.');
    if (n <= 0) return _text(context, 'La valeur doit être positive.');
    if (min != null && n < min) return '${_text(context, 'Minimum')}: $min.';
    if (max != null && n > max) return '${_text(context, 'Maximum')}: $max.';
    return null;
  }

  /// Non-null, positive double (e.g. price).
  static String? positiveDouble(String? value, {BuildContext? context}) {
    if (value == null || value.trim().isEmpty) {
      return _text(context, 'Ce champ est requis.');
    }
    final n = double.tryParse(value.trim().replaceAll(',', '.'));
    if (n == null) return _text(context, 'Valeur numérique invalide.');
    if (n < 0) return _text(context, 'La valeur ne peut pas être négative.');
    return null;
  }

  /// Phone: non-empty, reasonable length.
  static String? phone(String? value, {BuildContext? context}) {
    final err = required(value, 'Le téléphone est requis.', context);
    if (err != null) return err;
    final v = value!.trim();
    if (!RegExp(r'^\d+$').hasMatch(v)) {
      return _text(
          context, 'Le téléphone doit contenir uniquement des chiffres.');
    }
    if (v.length < 8) return _text(context, 'Numéro de téléphone trop court.');
    if (v.length > 20) return _text(context, 'Numéro de téléphone trop long.');
    return null;
  }

  /// Email: optional but if provided must look like an email.
  static String? emailOptional(String? value, {BuildContext? context}) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v)) {
      return _text(context, 'Adresse email invalide.');
    }
    return null;
  }

  /// CIN: non-empty, alphanumeric.
  static String? cin(String? value, {BuildContext? context}) {
    final err = required(value, 'Le CIN est requis.', context);
    if (err != null) return err;
    if (!RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(value!.trim())) {
      return _text(context,
          'CIN invalide (caractères autorisés: lettres, chiffres, tiret).');
    }
    return null;
  }

  /// Registration number: non-empty.
  static String? registrationNumber(String? value, {BuildContext? context}) {
    return required(value, 'L\'immatriculation est requise.', context);
  }
}
