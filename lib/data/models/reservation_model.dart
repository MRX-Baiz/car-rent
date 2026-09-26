import '../../domain/entities/reservation.dart';

/// SQLite representation of a [Reservation]. Keep mapping concerns here so
/// the domain entity remains independent from database column names.
class ReservationModel {
  const ReservationModel({
    this.id,
    required this.vehicleId,
    this.clientId,
    required this.startDate,
    required this.expectedReturnDate,
    required this.dailyPrice,
    required this.totalPrice,
    this.status = 'quote',
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
  final String status; // quote, cancelled, converted
  final String? notes;
  final int? convertedContractId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reservation toEntity() => Reservation(
        id: id,
        vehicleId: vehicleId,
        clientId: clientId,
        startDate: startDate,
        expectedReturnDate: expectedReturnDate,
        dailyPrice: dailyPrice,
        totalPrice: totalPrice,
        status: ReservationStatus.fromDatabaseValue(status),
        notes: notes,
        convertedContractId: convertedContractId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory ReservationModel.fromEntity(Reservation reservation) =>
      ReservationModel(
        id: reservation.id,
        vehicleId: reservation.vehicleId,
        clientId: reservation.clientId,
        startDate: reservation.startDate,
        expectedReturnDate: reservation.expectedReturnDate,
        dailyPrice: reservation.dailyPrice,
        totalPrice: reservation.totalPrice,
        status: reservation.status.databaseValue,
        notes: reservation.notes,
        convertedContractId: reservation.convertedContractId,
        createdAt: reservation.createdAt,
        updatedAt: reservation.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'client_id': clientId,
        'start_date': startDate.toIso8601String(),
        'expected_return_date': expectedReturnDate.toIso8601String(),
        'daily_price': dailyPrice,
        'total_price': totalPrice,
        'status': status,
        'notes': notes,
        'converted_contract_id': convertedContractId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ReservationModel.fromMap(Map<String, dynamic> map) =>
      ReservationModel(
        id: map['id'] as int?,
        vehicleId: map['vehicle_id'] as int,
        clientId: map['client_id'] as int?,
        startDate: DateTime.parse(map['start_date'] as String),
        expectedReturnDate:
            DateTime.parse(map['expected_return_date'] as String),
        dailyPrice: (map['daily_price'] as num).toDouble(),
        totalPrice: (map['total_price'] as num).toDouble(),
        status: map['status'] as String,
        notes: map['notes'] as String?,
        convertedContractId: map['converted_contract_id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
