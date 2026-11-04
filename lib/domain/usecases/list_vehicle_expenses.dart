import '../entities/vehicle_expense.dart';
import '../repositories/vehicle_expense_repository.dart';

class ListVehicleExpenses {
  const ListVehicleExpenses(this._repository);

  final VehicleExpenseRepository _repository;

  Future<List<VehicleExpense>> call(int vehicleId) {
    if (vehicleId <= 0) throw ArgumentError.value(vehicleId, 'vehicleId');
    return _repository.listForVehicle(vehicleId);
  }
}
