enum VehicleDocumentType { insurance, technicalInspection, roadTax }

class OperationsContract {
  const OperationsContract({
    required this.id,
    required this.vehicleId,
    required this.clientId,
    required this.startDate,
    required this.expectedReturnDate,
    required this.remainingAmount,
    required this.isCompleted,
  });

  final int id;
  final int vehicleId;
  final int clientId;
  final DateTime startDate;
  final DateTime expectedReturnDate;
  final double remainingAmount;
  final bool isCompleted;
}

class VehicleDocumentDeadline {
  const VehicleDocumentDeadline({
    required this.type,
    required this.dueDate,
  });

  final VehicleDocumentType type;
  final DateTime? dueDate;
}

class OperationsVehicle {
  const OperationsVehicle({
    required this.id,
    required this.isBlockedForMaintenance,
    required this.documents,
  });

  final int id;
  final bool isBlockedForMaintenance;
  final List<VehicleDocumentDeadline> documents;
}

class ExpiringDocument {
  const ExpiringDocument({
    required this.vehicleId,
    required this.type,
    required this.dueDate,
    required this.daysUntilDue,
  });

  final int vehicleId;
  final VehicleDocumentType type;
  final DateTime dueDate;
  final int daysUntilDue;
}

class TodayOperationsQueue {
  const TodayOperationsQueue({
    required this.pickups,
    required this.returns,
    required this.lateReturns,
    required this.unpaid,
    required this.blockedVehicleIds,
    required this.expiringDocuments,
  });

  final List<OperationsContract> pickups;
  final List<OperationsContract> returns;
  final List<OperationsContract> lateReturns;
  final List<OperationsContract> unpaid;
  final List<int> blockedVehicleIds;
  final List<ExpiringDocument> expiringDocuments;

  int get total =>
      pickups.length +
      returns.length +
      lateReturns.length +
      unpaid.length +
      blockedVehicleIds.length +
      expiringDocuments.length;
}
