/// What the reminder scheduler needs to know about a rental. A snapshot rather
/// than the persistence model, so the business layer never sees SQLite rows.
class ContractReminderPlan {
  const ContractReminderPlan({
    required this.contractId,
    required this.isActive,
    required this.registrationNumber,
    required this.startDate,
    required this.expectedReturnDate,
    required this.remainingAmount,
  });

  final int contractId;

  /// Only an active contract has reminders; a completed one must have none.
  final bool isActive;
  final String registrationNumber;
  final DateTime startDate;
  final DateTime expectedReturnDate;
  final double remainingAmount;
}

/// Dates and odometer thresholds behind a vehicle's maintenance reminders.
class VehicleMaintenancePlan {
  const VehicleMaintenancePlan({
    required this.vehicleId,
    required this.registrationNumber,
    required this.currentMileage,
    this.insuranceExpiryDate,
    this.technicalInspectionExpiryDate,
    this.vignetteDueDate,
    this.oilChangeDueDate,
    this.oilChangeDueMileage,
    this.distributionDueDate,
    this.distributionDueMileage,
  });

  final int vehicleId;
  final String registrationNumber;
  final int currentMileage;
  final DateTime? insuranceExpiryDate;
  final DateTime? technicalInspectionExpiryDate;
  final DateTime? vignetteDueDate;
  final DateTime? oilChangeDueDate;
  final int? oilChangeDueMileage;
  final DateTime? distributionDueDate;
  final int? distributionDueMileage;
}
