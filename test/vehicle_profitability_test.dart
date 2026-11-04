import 'package:car_rent_manager/domain/entities/vehicle_expense.dart';
import 'package:car_rent_manager/domain/entities/vehicle_profitability.dart';
import 'package:car_rent_manager/domain/usecases/compute_vehicle_profitability.dart';
import 'package:flutter_test/flutter_test.dart';

/// [ComputeVehicleProfitability] is what tells the operator which vehicles are
/// worth buying again and which are losing money, so these tests exercise the
/// formula directly rather than through fakes — it's pure, so plain data is
/// enough.
void main() {
  const compute = ComputeVehicleProfitability();
  final now = DateTime(2026, 9, 28);

  ProfitabilityContract completed({
    required int vehicleId,
    required DateTime start,
    required DateTime end,
    required double amountPaid,
  }) =>
      ProfitabilityContract(
        vehicleId: vehicleId,
        startDate: start,
        actualReturnDate: end,
        isActive: false,
        amountPaid: amountPaid,
      );

  ProfitabilityContract active({
    required int vehicleId,
    required DateTime start,
    required double amountPaid,
  }) =>
      ProfitabilityContract(
        vehicleId: vehicleId,
        startDate: start,
        actualReturnDate: null,
        isActive: true,
        amountPaid: amountPaid,
      );

  VehicleExpense expense(
    int vehicleId,
    VehicleExpenseCategory category,
    double amount,
  ) =>
      VehicleExpense(
        id: null,
        vehicleId: vehicleId,
        category: category,
        amount: amount,
        date: now,
      );

  test('a completed contract with no expenses is pure profit', () {
    final result = compute(
      vehicleId: 1,
      contracts: [
        completed(
          vehicleId: 1,
          start: now.subtract(const Duration(days: 10)),
          end: now.subtract(const Duration(days: 5)),
          amountPaid: 1000,
        ),
      ],
      expenses: const [],
      addedAt: now.subtract(const Duration(days: 100)),
      now: now,
    );

    expect(result.revenue, 1000);
    expect(result.rentalDays, 5);
    expect(result.totalExpenses, 0);
    expect(result.netProfit, 1000);
  });

  test('an in-progress rental counts days up to now, not to an end date', () {
    final result = compute(
      vehicleId: 1,
      contracts: [
        active(
          vehicleId: 1,
          start: now.subtract(const Duration(days: 3)),
          amountPaid: 200,
        ),
      ],
      expenses: const [],
      addedAt: now.subtract(const Duration(days: 30)),
      now: now,
    );

    expect(result.rentalDays, 3);
    expect(result.revenue, 200);
  });

  test('expenses group by category and reduce net profit', () {
    final result = compute(
      vehicleId: 2,
      contracts: [
        completed(
          vehicleId: 2,
          start: now.subtract(const Duration(days: 20)),
          end: now.subtract(const Duration(days: 10)),
          amountPaid: 2000,
        ),
      ],
      expenses: [
        expense(2, VehicleExpenseCategory.repair, 300),
        expense(2, VehicleExpenseCategory.repair, 150),
        expense(2, VehicleExpenseCategory.insurance, 400),
        expense(2, VehicleExpenseCategory.fine, 100),
      ],
      addedAt: now.subtract(const Duration(days: 200)),
      now: now,
    );

    expect(result.expensesByCategory[VehicleExpenseCategory.repair], 450);
    expect(result.expensesByCategory[VehicleExpenseCategory.insurance], 400);
    expect(result.expensesByCategory[VehicleExpenseCategory.fine], 100);
    expect(result.expensesByCategory[VehicleExpenseCategory.other], isNull);
    expect(result.totalExpenses, 950);
    expect(result.netProfit, 2000 - 950);
  });

  test('a vehicle added today has no divide-by-zero and no false utilization',
      () {
    final result = compute(
      vehicleId: 3,
      contracts: const [],
      expenses: const [],
      addedAt: now,
      now: now,
    );

    expect(result.daysTracked, 0);
    expect(result.utilizationPercent, isNull);
  });

  test('utilization is rental days over days tracked, clamped at 100', () {
    final result = compute(
      vehicleId: 4,
      contracts: [
        completed(
          vehicleId: 4,
          start: now.subtract(const Duration(days: 100)),
          end: now.subtract(const Duration(days: 50)),
          amountPaid: 500,
        ),
      ],
      expenses: const [],
      addedAt: now.subtract(const Duration(days: 100)),
      now: now,
    );

    // 50 rental days / 100 tracked days = 50%.
    expect(result.utilizationPercent, 50);
  });

  test('a vehicle with only expenses and no contracts is a pure loss', () {
    final result = compute(
      vehicleId: 5,
      contracts: const [],
      expenses: [expense(5, VehicleExpenseCategory.insurance, 600)],
      addedAt: now.subtract(const Duration(days: 60)),
      now: now,
    );

    expect(result.revenue, 0);
    expect(result.rentalDays, 0);
    expect(result.netProfit, -600);
  });

  test('only contracts and expenses for the requested vehicle are counted',
      () {
    final result = compute(
      vehicleId: 1,
      contracts: [
        completed(
          vehicleId: 1,
          start: now.subtract(const Duration(days: 10)),
          end: now.subtract(const Duration(days: 5)),
          amountPaid: 500,
        ),
        completed(
          vehicleId: 2,
          start: now.subtract(const Duration(days: 10)),
          end: now.subtract(const Duration(days: 5)),
          amountPaid: 9000,
        ),
      ],
      expenses: [
        expense(1, VehicleExpenseCategory.repair, 50),
        expense(2, VehicleExpenseCategory.repair, 9999),
      ],
      addedAt: now.subtract(const Duration(days: 30)),
      now: now,
    );

    expect(result.revenue, 500);
    expect(result.totalExpenses, 50);
  });
}
