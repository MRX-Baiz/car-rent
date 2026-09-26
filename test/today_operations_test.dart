import 'package:car_rent_manager/domain/entities/today_operations.dart';
import 'package:car_rent_manager/domain/usecases/build_today_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 12);
  final vehicle = OperationsVehicle(
    id: 1,
    isBlockedForMaintenance: true,
    documents: [
      VehicleDocumentDeadline(
        type: VehicleDocumentType.insurance,
        dueDate: now,
      ),
    ],
  );

  OperationsContract contract({
    required int id,
    required DateTime start,
    required DateTime expectedReturn,
    double paid = 100,
  }) =>
      OperationsContract(
        id: id,
        vehicleId: 1,
        clientId: 1,
        startDate: start,
        expectedReturnDate: expectedReturn,
        remainingAmount: 100 - paid,
        isCompleted: false,
      );

  test('builds today’s queue from contracts and vehicle records', () {
    final queue = const BuildTodayOperations()(
      now: now,
      vehicles: [vehicle],
      contracts: [
        contract(
            id: 1,
            start: now,
            expectedReturn: now.add(const Duration(days: 2))),
        contract(
            id: 2,
            start: now.subtract(const Duration(days: 2)),
            expectedReturn: now),
        contract(
            id: 3,
            start: now.subtract(const Duration(days: 4)),
            expectedReturn: now.subtract(const Duration(days: 1)),
            paid: 30),
      ],
    );

    expect(queue.pickups, hasLength(1));
    expect(queue.returns, hasLength(1));
    expect(queue.lateReturns, hasLength(1));
    expect(queue.unpaid, hasLength(1));
    expect(queue.blockedVehicleIds, hasLength(1));
    expect(queue.expiringDocuments, hasLength(1));
  });
}
