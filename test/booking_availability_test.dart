import 'package:car_rent_manager/domain/usecases/booking_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final morning = DateTime(2026, 9, 24, 9);

  test('overlapping reservations are detected', () {
    expect(
      bookingIntervalsOverlap(
        morning,
        morning.add(const Duration(days: 3)),
        morning.add(const Duration(days: 2)),
        morning.add(const Duration(days: 4)),
      ),
      isTrue,
    );
  });

  test('back-to-back reservations remain available', () {
    expect(
      bookingIntervalsOverlap(
        morning,
        morning.add(const Duration(days: 2)),
        morning.add(const Duration(days: 2)),
        morning.add(const Duration(days: 4)),
      ),
      isFalse,
    );
  });
}
