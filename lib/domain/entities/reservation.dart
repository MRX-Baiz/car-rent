enum ReservationStatus {
  quote,
  cancelled,
  converted;

  String get databaseValue => name;

  static ReservationStatus fromDatabaseValue(String value) =>
      ReservationStatus.values.firstWhere(
        (status) => status.databaseValue == value,
        orElse: () => ReservationStatus.quote,
      );
}

/// A planned rental held before it becomes an active contract.
///
/// This entity deliberately contains no SQLite or UI concerns. It can be used
/// by any storage implementation, test, or future API without changing the
/// reservation rules.
class Reservation {
  const Reservation({
    this.id,
    required this.vehicleId,
    this.clientId,
    required this.startDate,
    required this.expectedReturnDate,
    required this.dailyPrice,
    required this.totalPrice,
    this.status = ReservationStatus.quote,
    this.notes,
    this.convertedContractId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int vehicleId;
  final int? clientId;
  final DateTime startDate;
  final DateTime expectedReturnDate;
  final double dailyPrice;
  final double totalPrice;
  final ReservationStatus status;
  final String? notes;
  final int? convertedContractId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get blocksAvailability => status == ReservationStatus.quote;

  int get rentalDays {
    final days = expectedReturnDate.difference(startDate).inDays;
    return days < 1 ? 1 : days;
  }

  Reservation copyWith({
    int? id,
    int? vehicleId,
    int? clientId,
    DateTime? startDate,
    DateTime? expectedReturnDate,
    double? dailyPrice,
    double? totalPrice,
    ReservationStatus? status,
    String? notes,
    int? convertedContractId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Reservation(
        id: id ?? this.id,
        vehicleId: vehicleId ?? this.vehicleId,
        clientId: clientId ?? this.clientId,
        startDate: startDate ?? this.startDate,
        expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
        dailyPrice: dailyPrice ?? this.dailyPrice,
        totalPrice: totalPrice ?? this.totalPrice,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        convertedContractId: convertedContractId ?? this.convertedContractId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
