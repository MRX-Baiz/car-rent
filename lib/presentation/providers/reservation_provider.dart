import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/reservation_repository.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/repositories/reservation_repository.dart';
import '../../domain/usecases/cancel_reservation_quote.dart';
import '../../domain/usecases/create_reservation_quote.dart';
import '../../domain/usecases/list_reservations.dart';

/// Presentation depends on use cases and a domain interface. SQLite remains
/// behind this provider and can later be replaced by an API implementation.
final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return SqliteReservationRepository.instance;
});

final listReservationsProvider = Provider<ListReservations>((ref) {
  return ListReservations(ref.watch(reservationRepositoryProvider));
});

final createReservationQuoteProvider = Provider<CreateReservationQuote>((ref) {
  return CreateReservationQuote(ref.watch(reservationRepositoryProvider));
});

final cancelReservationQuoteProvider = Provider<CancelReservationQuote>((ref) {
  return CancelReservationQuote(ref.watch(reservationRepositoryProvider));
});

final reservationsProvider = FutureProvider<List<Reservation>>((ref) {
  return ref.watch(listReservationsProvider)();
});
