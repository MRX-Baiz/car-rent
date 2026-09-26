import '../../core/database/database_helper.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/repositories/reservation_repository.dart';
import '../models/reservation_model.dart';

/// SQLite implementation of the reservation storage contract.
class SqliteReservationRepository implements ReservationRepository {
  SqliteReservationRepository._internal();

  static final instance = SqliteReservationRepository._internal();

  @override
  Future<List<Reservation>> listAll() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('reservations', orderBy: 'start_date ASC');
    return rows
        .map(ReservationModel.fromMap)
        .map((model) => model.toEntity())
        .toList();
  }

  /// Creates a quote only if no active contract or other open quote occupies
  /// any part of the requested interval. Adjacent bookings are allowed.
  @override
  Future<int> createQuote(Reservation reservation) async {
    if (!reservation.expectedReturnDate.isAfter(reservation.startDate)) {
      throw Exception('Choisissez une date de retour après la date de départ.');
    }
    final db = await DatabaseHelper.instance.database;
    return db.transaction((txn) async {
      final vehicle = await txn.query(
        'vehicles',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [reservation.vehicleId],
        limit: 1,
      );
      if (vehicle.isEmpty || vehicle.single['status'] == 'maintenance') {
        throw Exception('Ce véhicule est indisponible pour entretien.');
      }
      final unavailable = await _hasConflict(
        txn,
        vehicleId: reservation.vehicleId,
        start: reservation.startDate,
        end: reservation.expectedReturnDate,
      );
      if (unavailable) {
        throw Exception('Ce véhicule est déjà réservé sur cette période.');
      }
      return txn.insert(
        'reservations',
        ReservationModel.fromEntity(reservation).toMap()..remove('id'),
      );
    });
  }

  @override
  Future<void> cancelQuote(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'reservations',
      {'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'quote'],
    );
  }

  static Future<bool> _hasConflict(
    dynamic txn, {
    required int vehicleId,
    required DateTime start,
    required DateTime end,
  }) async {
    final endIso = end.toIso8601String();
    final startIso = start.toIso8601String();
    final contracts = await txn.query(
      'contracts',
      columns: ['id'],
      where:
          "vehicle_id = ? AND status = 'active' AND start_date < ? AND expected_return_date > ?",
      whereArgs: [vehicleId, endIso, startIso],
      limit: 1,
    );
    if (contracts.isNotEmpty) return true;
    final reservations = await txn.query(
      'reservations',
      columns: ['id'],
      where:
          "vehicle_id = ? AND status = 'quote' AND start_date < ? AND expected_return_date > ?",
      whereArgs: [vehicleId, endIso, startIso],
      limit: 1,
    );
    return reservations.isNotEmpty;
  }
}
