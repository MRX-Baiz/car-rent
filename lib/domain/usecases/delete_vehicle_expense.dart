import '../repositories/vehicle_expense_repository.dart';

class DeleteVehicleExpense {
  const DeleteVehicleExpense(this._repository);

  final VehicleExpenseRepository _repository;

  Future<void> call(int expenseId) {
    if (expenseId <= 0) throw ArgumentError.value(expenseId, 'expenseId');
    return _repository.deleteExpense(expenseId);
  }
}
