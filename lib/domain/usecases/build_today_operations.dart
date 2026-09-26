import '../entities/today_operations.dart';

/// Produces the operational queue for one calendar day.
///
/// It only knows about domain data. Naming, currency formatting, icons, and
/// translated labels remain in the presentation layer.
class BuildTodayOperations {
  const BuildTodayOperations({this.documentWarningDays = 30});

  final int documentWarningDays;

  TodayOperationsQueue call({
    required Iterable<OperationsContract> contracts,
    required Iterable<OperationsVehicle> vehicles,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final open = contracts.where((contract) => !contract.isCompleted).toList();
    final documents = <ExpiringDocument>[];

    for (final vehicle in vehicles) {
      for (final document in vehicle.documents) {
        final dueDate = document.dueDate;
        if (dueDate == null) continue;
        final daysUntilDue = _dateOnly(dueDate).difference(today).inDays;
        if (daysUntilDue <= documentWarningDays) {
          documents.add(
            ExpiringDocument(
              vehicleId: vehicle.id,
              type: document.type,
              dueDate: dueDate,
              daysUntilDue: daysUntilDue,
            ),
          );
        }
      }
    }
    documents.sort(
        (first, second) => first.daysUntilDue.compareTo(second.daysUntilDue));

    return TodayOperationsQueue(
      pickups: open
          .where((contract) => _dateOnly(contract.startDate) == today)
          .toList(),
      returns: open
          .where((contract) => _dateOnly(contract.expectedReturnDate) == today)
          .toList(),
      lateReturns: open
          .where((contract) => contract.expectedReturnDate.isBefore(today))
          .toList(),
      unpaid:
          open.where((contract) => contract.remainingAmount > 0.009).toList()
            ..sort((first, second) =>
                second.remainingAmount.compareTo(first.remainingAmount)),
      blockedVehicleIds: vehicles
          .where((vehicle) => vehicle.isBlockedForMaintenance)
          .map((vehicle) => vehicle.id)
          .toList(),
      expiringDocuments: documents,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
