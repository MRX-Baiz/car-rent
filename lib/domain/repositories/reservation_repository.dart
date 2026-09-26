import '../entities/reservation.dart';

/// The contract the business layer needs from reservation storage.
/// SQLite is only one possible implementation.
abstract interface class ReservationRepository {
  Future<List<Reservation>> listAll();
  Future<int> createQuote(Reservation reservation);
  Future<void> cancelQuote(int id);
}
