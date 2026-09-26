import '../entities/reservation.dart';
import '../repositories/reservation_repository.dart';

class CreateReservationQuote {
  const CreateReservationQuote(this._repository);

  final ReservationRepository _repository;

  Future<int> call(Reservation reservation) {
    if (!reservation.expectedReturnDate.isAfter(reservation.startDate)) {
      throw ArgumentError(
        'Choisissez une date de retour après la date de départ.',
      );
    }
    return _repository.createQuote(reservation);
  }
}
