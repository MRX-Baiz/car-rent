import '../repositories/reservation_repository.dart';

class CancelReservationQuote {
  const CancelReservationQuote(this._repository);

  final ReservationRepository _repository;

  Future<void> call(int reservationId) =>
      _repository.cancelQuote(reservationId);
}
