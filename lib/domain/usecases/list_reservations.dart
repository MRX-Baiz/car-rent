import '../entities/reservation.dart';
import '../repositories/reservation_repository.dart';

class ListReservations {
  const ListReservations(this._repository);

  final ReservationRepository _repository;

  Future<List<Reservation>> call() => _repository.listAll();
}
