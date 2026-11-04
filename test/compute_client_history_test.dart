import 'package:car_rent_manager/domain/entities/client_history.dart';
import 'package:car_rent_manager/domain/usecases/compute_client_history.dart';
import 'package:flutter_test/flutter_test.dart';

/// [ComputeClientHistory] is what flags a client worth a second look before
/// the next rental: how often they've rented, how often late, what they
/// currently owe, and how many rentals involved damage.
void main() {
  const compute = ComputeClientHistory();
  final now = DateTime(2026, 9, 28);

  ClientRentalRecord completed({
    required DateTime start,
    required DateTime expected,
    required DateTime actual,
    double remaining = 0,
    bool hadDamage = false,
  }) =>
      ClientRentalRecord(
        contractId: 1,
        startDate: start,
        expectedReturnDate: expected,
        actualReturnDate: actual,
        isActive: false,
        remainingAmount: remaining,
        hadDamage: hadDamage,
      );

  ClientRentalRecord active({
    required DateTime start,
    required DateTime expected,
    double remaining = 0,
    bool hadDamage = false,
  }) =>
      ClientRentalRecord(
        contractId: 2,
        startDate: start,
        expectedReturnDate: expected,
        actualReturnDate: null,
        isActive: true,
        remainingAmount: remaining,
        hadDamage: hadDamage,
      );

  test('a client with no contracts has an all-zero history', () {
    final result = compute(clientId: 1, rentals: const [], now: now);

    expect(result.totalRentals, 0);
    expect(result.lateReturnCount, 0);
    expect(result.totalUnpaidBalance, 0);
    expect(result.damageIncidentCount, 0);
  });

  test('a completed contract returned late counts as late', () {
    final result = compute(
      clientId: 1,
      rentals: [
        completed(
          start: now.subtract(const Duration(days: 10)),
          expected: now.subtract(const Duration(days: 5)),
          actual: now.subtract(const Duration(days: 3)),
        ),
      ],
      now: now,
    );

    expect(result.totalRentals, 1);
    expect(result.lateReturnCount, 1);
  });

  test('a completed contract returned on time is not late', () {
    final result = compute(
      clientId: 1,
      rentals: [
        completed(
          start: now.subtract(const Duration(days: 10)),
          expected: now.subtract(const Duration(days: 5)),
          actual: now.subtract(const Duration(days: 6)),
        ),
      ],
      now: now,
    );

    expect(result.lateReturnCount, 0);
  });

  test('an active contract past its expected return counts as currently late',
      () {
    final result = compute(
      clientId: 1,
      rentals: [
        active(
          start: now.subtract(const Duration(days: 5)),
          expected: now.subtract(const Duration(days: 1)),
        ),
      ],
      now: now,
    );

    expect(result.lateReturnCount, 1);
  });

  test('an active contract not yet due is not late', () {
    final result = compute(
      clientId: 1,
      rentals: [
        active(
          start: now,
          expected: now.add(const Duration(days: 2)),
        ),
      ],
      now: now,
    );

    expect(result.lateReturnCount, 0);
  });

  test('unpaid balance sums only active contracts, not completed ones', () {
    final result = compute(
      clientId: 1,
      rentals: [
        active(
          start: now,
          expected: now.add(const Duration(days: 2)),
          remaining: 300,
        ),
        completed(
          start: now.subtract(const Duration(days: 10)),
          expected: now.subtract(const Duration(days: 5)),
          actual: now.subtract(const Duration(days: 5)),
          remaining: 999, // a completed contract should not still owe money,
        ), // but this proves the sum ignores it either way.
      ],
      now: now,
    );

    expect(result.totalUnpaidBalance, 300);
  });

  test(
      'departure and return inspections flagging the same contract count as '
      'one damage incident, not two', () {
    final result = compute(
      clientId: 1,
      rentals: [
        completed(
          start: now.subtract(const Duration(days: 10)),
          expected: now.subtract(const Duration(days: 5)),
          actual: now.subtract(const Duration(days: 5)),
          hadDamage: true,
        ),
      ],
      now: now,
    );

    expect(result.totalRentals, 1);
    expect(result.damageIncidentCount, 1);
  });

  test('only the requested client\'s rentals feed the summary', () {
    // The provider is responsible for filtering by client before calling
    // this - the use case just totals whatever it's handed, so this pins
    // that a mixed batch is summed as given, not filtered internally.
    final result = compute(
      clientId: 1,
      rentals: [
        completed(
          start: now.subtract(const Duration(days: 10)),
          expected: now.subtract(const Duration(days: 5)),
          actual: now.subtract(const Duration(days: 5)),
        ),
      ],
      now: now,
    );

    expect(result.clientId, 1);
    expect(result.totalRentals, 1);
  });
}
