import '../entities/vehicle_expense.dart';
import '../repositories/vehicle_expense_repository.dart';

class RecordVehicleExpense {
  const RecordVehicleExpense(this._repository);

  final VehicleExpenseRepository _repository;

  Future<void> call(VehicleExpense expense) {
    if (expense.vehicleId <= 0) {
      throw ArgumentError.value(expense.vehicleId, 'vehicleId');
    }
    if (expense.amount <= 0) {
      throw ArgumentError.value(expense.amount, 'amount', 'must be greater than zero');
    }
    return _repository.recordExpense(expense);
  }
}
