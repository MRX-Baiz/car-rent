import '../entities/vehicle_expense.dart';

/// Storage for money spent on a vehicle, independent from SQLite.
abstract interface class VehicleExpenseRepository {
  Future<void> recordExpense(VehicleExpense expense);

  Future<List<VehicleExpense>> listForVehicle(int vehicleId);

  /// Every expense across the fleet, for the profitability report — one
  /// query instead of one per vehicle.
  Future<List<VehicleExpense>> listAll();

  Future<void> deleteExpense(int expenseId);
}
