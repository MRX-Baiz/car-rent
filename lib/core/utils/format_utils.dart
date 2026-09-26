import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

final _date = DateFormat('dd/MM/yyyy');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final _time = DateFormat('HH:mm');

String formatDate(DateTime value) => _date.format(value);
String formatDateTime(DateTime value) => _dateTime.format(value);
String formatTime(DateTime value) => _time.format(value);

/// "1 250 MAD", or "1 250,50 MAD" when there are cents. A narrow no-break
/// space keeps long amounts grouped without wrapping mid-number.
String formatMad(num value) {
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  final cents = parts[1] == '00' ? '' : ',${parts[1]}';
  return '${value < 0 ? '-' : ''}$grouped$cents MAD';
}

String formatKm(int value) {
  final grouped = value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ' ',
      );
  return '$grouped km';
}

const _weekdays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// "Dimanche 20 septembre" without needing locale data to be initialised.
String formatLongDay(DateTime value, {Locale? locale}) {
  if (locale != null && locale.languageCode != 'fr') {
    return DateFormat('EEEE d MMMM', locale.toLanguageTag()).format(value);
  }
  final weekday = _weekdays[value.weekday - 1];
  return '${weekday[0].toUpperCase()}${weekday.substring(1)} '
      '${value.day} ${_months[value.month - 1]}';
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// A date-driven deadline (insurance, licence, ...) turned into something the
/// operator can read at a glance.
class ExpiryStatus {
  const ExpiryStatus({
    required this.tone,
    required this.label,
    required this.needsAttention,
    required this.daysLeft,
  });

  final AppTone tone;
  final String label;
  final bool needsAttention;
  final int? daysLeft;
}

ExpiryStatus expiryOf(
  DateTime? date, {
  int soonDays = 30,
  DateTime? now,
}) {
  if (date == null) {
    return const ExpiryStatus(
      tone: AppTone.neutral,
      label: 'Non renseigné',
      needsAttention: false,
      daysLeft: null,
    );
  }
  final days =
      dateOnly(date).difference(dateOnly(now ?? DateTime.now())).inDays;
  if (days < 0) {
    return ExpiryStatus(
      tone: AppTone.danger,
      label: 'Expiré depuis ${-days} j',
      needsAttention: true,
      daysLeft: days,
    );
  }
  if (days == 0) {
    return const ExpiryStatus(
      tone: AppTone.danger,
      label: 'Expire aujourd’hui',
      needsAttention: true,
      daysLeft: 0,
    );
  }
  if (days <= soonDays) {
    return ExpiryStatus(
      tone: AppTone.warning,
      label: 'Expire dans $days j',
      needsAttention: true,
      daysLeft: days,
    );
  }
  return ExpiryStatus(
    tone: AppTone.success,
    label: 'Valide',
    needsAttention: false,
    daysLeft: days,
  );
}
