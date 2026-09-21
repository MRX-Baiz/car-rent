import 'package:flutter/material.dart';

import '../../data/models/vehicle_model.dart';
import '../constants/app_colors.dart';
import 'format_utils.dart';

/// One legal document or service interval of a vehicle, already judged.
class MaintenanceItem {
  const MaintenanceItem({
    required this.label,
    required this.icon,
    required this.value,
    required this.status,
    required this.tone,
    required this.needsAttention,
    required this.urgency,
    required this.isSet,
  });

  final String label;
  final IconData icon;

  /// The deadline itself: a date or a mileage.
  final String value;

  /// The judgement: "Expire dans 12 j", "Valide", "Dépassée de 300 km"...
  final String status;
  final AppTone tone;
  final bool needsAttention;

  /// Smaller is more urgent; used to sort the dashboard alerts.
  final int urgency;
  final bool isSet;
}

const _kmWarning = 1000;

// Mileage and dates are ranked on one scale by assuming a rental car covers
// roughly 100 km a day, so 500 km left reads as "about 5 days".
const _kmPerDay = 100;

MaintenanceItem _dateItem(
  String label,
  IconData icon,
  DateTime? date,
  DateTime now,
) {
  final status = expiryOf(date, now: now);
  return MaintenanceItem(
    label: label,
    icon: icon,
    value: date == null ? 'Non renseignée' : formatDate(date),
    status: status.label,
    tone: status.tone,
    needsAttention: status.needsAttention,
    urgency: status.daysLeft ?? 100000,
    isSet: date != null,
  );
}

/// A service due by date, by mileage, or both; the worse of the two wins.
MaintenanceItem _serviceItem({
  required String label,
  required IconData icon,
  required DateTime? dueDate,
  required int? dueMileage,
  required int currentMileage,
  required DateTime now,
}) {
  if (dueDate == null && dueMileage == null) {
    return MaintenanceItem(
      label: label,
      icon: icon,
      value: 'Non renseignée',
      status: 'Non renseigné',
      tone: AppTone.neutral,
      needsAttention: false,
      urgency: 100000,
      isSet: false,
    );
  }

  final byDate = dueDate == null ? null : expiryOf(dueDate, now: now);
  ExpiryStatus? byKm;
  if (dueMileage != null) {
    final left = dueMileage - currentMileage;
    if (left <= 0) {
      byKm = ExpiryStatus(
        tone: AppTone.danger,
        label: 'Dépassée de ${formatKm(-left)}',
        needsAttention: true,
        daysLeft: left ~/ _kmPerDay,
      );
    } else if (left <= _kmWarning) {
      byKm = ExpiryStatus(
        tone: AppTone.warning,
        label: 'Dans ${formatKm(left)}',
        needsAttention: true,
        daysLeft: left ~/ _kmPerDay,
      );
    } else {
      byKm = ExpiryStatus(
        tone: AppTone.success,
        label: 'Dans ${formatKm(left)}',
        needsAttention: false,
        daysLeft: left ~/ _kmPerDay,
      );
    }
  }

  int rank(ExpiryStatus? s) => s == null
      ? -1
      : switch (s.tone) {
          AppTone.danger => 2,
          AppTone.warning => 1,
          _ => 0,
        };
  final worst = rank(byDate) >= rank(byKm) ? byDate! : byKm!;
  final parts = <String>[
    if (dueDate != null) formatDate(dueDate),
    if (dueMileage != null) formatKm(dueMileage),
  ];
  return MaintenanceItem(
    label: label,
    icon: icon,
    value: parts.join(' · '),
    status: worst.label,
    tone: worst.tone,
    needsAttention: worst.needsAttention,
    urgency: worst.daysLeft ?? 100000,
    isSet: true,
  );
}

List<MaintenanceItem> maintenanceItems(VehicleModel v, {DateTime? now}) {
  final at = now ?? DateTime.now();
  return [
    _dateItem('Assurance', Icons.shield_outlined, v.insuranceExpiryDate, at),
    _dateItem('Visite technique', Icons.fact_check_outlined,
        v.technicalInspectionExpiryDate, at),
    _dateItem('Vignette', Icons.receipt_outlined, v.vignetteDueDate, at),
    _serviceItem(
      label: 'Vidange',
      icon: Icons.oil_barrel_outlined,
      dueDate: v.oilChangeDueDate,
      dueMileage: v.oilChangeDueMileage,
      currentMileage: v.currentMileage,
      now: at,
    ),
    _serviceItem(
      label: 'Courroie / chaîne',
      icon: Icons.settings_outlined,
      dueDate: v.distributionDueDate,
      dueMileage: v.distributionDueMileage,
      currentMileage: v.currentMileage,
      now: at,
    ),
  ];
}

/// Only what needs the operator's attention, most urgent first.
List<MaintenanceItem> maintenanceAlerts(VehicleModel v, {DateTime? now}) {
  final list =
      maintenanceItems(v, now: now).where((i) => i.needsAttention).toList();
  list.sort((a, b) => a.urgency.compareTo(b.urgency));
  return list;
}
