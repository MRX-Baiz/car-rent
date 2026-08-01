/// Form and input validators used across the app.
class Validators {
  /// Non-empty string.
  static String? required(String? value, [String message = 'Ce champ est requis.']) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  /// Non-null, positive integer (e.g. year).
  static String? positiveInt(String? value, {int? min, int? max}) {
    if (value == null || value.trim().isEmpty) return 'Ce champ est requis.';
    final n = int.tryParse(value.trim());
    if (n == null) return 'Valeur numérique invalide.';
    if (n <= 0) return 'La valeur doit être positive.';
    if (min != null && n < min) return 'Minimum: $min.';
    if (max != null && n > max) return 'Maximum: $max.';
    return null;
  }

  /// Non-null, positive double (e.g. price).
  static String? positiveDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ce champ est requis.';
    final n = double.tryParse(value.trim().replaceAll(',', '.'));
    if (n == null) return 'Valeur numérique invalide.';
    if (n < 0) return 'La valeur ne peut pas être négative.';
    return null;
  }

  /// Phone: non-empty, reasonable length.
  static String? phone(String? value) {
    final err = required(value, 'Le téléphone est requis.');
    if (err != null) return err;
    final v = value!.trim();
    if (!RegExp(r'^\d+$').hasMatch(v)) {
      return 'Le téléphone doit contenir uniquement des chiffres.';
    }
    if (v.length < 8) return 'Numéro de téléphone trop court.';
    if (v.length > 20) return 'Numéro de téléphone trop long.';
    return null;
  }

  /// Email: optional but if provided must look like an email.
  static String? emailOptional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v)) {
      return 'Adresse email invalide.';
    }
    return null;
  }

  /// CIN: non-empty, alphanumeric.
  static String? cin(String? value) {
    final err = required(value, 'Le CIN est requis.');
    if (err != null) return err;
    if (!RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(value!.trim())) {
      return 'CIN invalide (caractères autorisés: lettres, chiffres, tiret).';
    }
    return null;
  }

  /// Registration number: non-empty.
  static String? registrationNumber(String? value) {
    return required(value, 'L\'immatriculation est requise.');
  }
}
