import 'package:car_rent_manager/domain/entities/reservation.dart';
import 'package:car_rent_manager/domain/repositories/reservation_repository.dart';
import 'package:car_rent_manager/domain/usecases/cancel_reservation_quote.dart';
import 'package:car_rent_manager/domain/usecases/create_reservation_quote.dart';
import 'package:car_rent_manager/domain/usecases/list_reservations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 25, 9);
  final quote = Reservation(
    vehicleId: 3,
    startDate: now,
    expectedReturnDate: now.add(const Duration(days: 2)),
    dailyPrice: 300,
    totalPrice: 600,
    createdAt: now,
    updatedAt: now,
  );

  test('quote use cases only require the domain repository contract', () async {
    final repository = _InMemoryReservationRepository();
    final createQuote = CreateReservationQuote(repository);
    final listReservations = ListReservations(repository);
    final cancelQuote = CancelReservationQuote(repository);

    final id = await createQuote(quote);
    expect(id, 1);
    expect((await listReservations()).single.blocksAvailability, isTrue);

    await cancelQuote(id);
    expect(
        (await listReservations()).single.status, ReservationStatus.cancelled);
  });

  test('a quote must end after it starts', () {
    final repository = _InMemoryReservationRepository();
    final createQuote = CreateReservationQuote(repository);
    expect(
      () => createQuote(quote.copyWith(expectedReturnDate: quote.startDate)),
      throwsArgumentError,
    );
  });
}

class _InMemoryReservationRepository implements ReservationRepository {
  final List<Reservation> _reservations = [];

  @override
  Future<void> cancelQuote(int id) async {
    final index =
        _reservations.indexWhere((reservation) => reservation.id == id);
    _reservations[index] = _reservations[index].copyWith(
      status: ReservationStatus.cancelled,
    );
  }

  @override
  Future<int> createQuote(Reservation reservation) async {
    final id = _reservations.length + 1;
    _reservations.add(reservation.copyWith(id: id));
    return id;
  }

  @override
  Future<List<Reservation>> listAll() async => List.unmodifiable(_reservations);
}
