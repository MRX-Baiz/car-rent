import 'package:car_rent_manager/domain/entities/vehicle_expense.dart';
import 'package:car_rent_manager/domain/repositories/vehicle_expense_repository.dart';
import 'package:car_rent_manager/domain/usecases/delete_vehicle_expense.dart';
import 'package:car_rent_manager/domain/usecases/list_vehicle_expenses.dart';
import 'package:car_rent_manager/domain/usecases/record_vehicle_expense.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleExpense _expense({int vehicleId = 4, double amount = 300}) =>
    VehicleExpense(
      id: null,
      vehicleId: vehicleId,
      category: VehicleExpenseCategory.repair,
      amount: amount,
      date: DateTime(2026, 9, 1),
      notes: 'Vidange et plaquettes',
    );

void main() {
  test('records and lists an expense through the domain contract', () async {
    final repository = _FakeVehicleExpenseRepository();
    final record = RecordVehicleExpense(repository);
    final list = ListVehicleExpenses(repository);

    await record(_expense());

    final expenses = await list(4);
    expect(expenses, hasLength(1));
    expect(expenses.single.amount, 300);
    expect(expenses.single.category, VehicleExpenseCategory.repair);
  });

  test('rejects a zero or negative amount before reaching storage', () {
    final repository = _FakeVehicleExpenseRepository();
    final record = RecordVehicleExpense(repository);

    expect(() => record(_expense(amount: 0)), throwsArgumentError);
    expect(() => record(_expense(amount: -50)), throwsArgumentError);
    expect(repository.recorded, isEmpty);
  });

  test('rejects an invalid vehicle id before reaching storage', () {
    final repository = _FakeVehicleExpenseRepository();
    final record = RecordVehicleExpense(repository);

    expect(() => record(_expense(vehicleId: 0)), throwsArgumentError);
  });

  test('listAll returns every expense across vehicles, one query', () async {
    final repository = _FakeVehicleExpenseRepository();
    final record = RecordVehicleExpense(repository);
    await record(_expense(vehicleId: 1));
    await record(_expense(vehicleId: 2));

    expect(await repository.listAll(), hasLength(2));
  });

  test('deletes an expense through the domain contract', () async {
    final repository = _FakeVehicleExpenseRepository();
    await RecordVehicleExpense(repository)(_expense());
    final id = repository.recorded.single.id;

    await DeleteVehicleExpense(repository)(id!);

    expect(await ListVehicleExpenses(repository)(4), isEmpty);
  });

  test('rejects an invalid expense id before reaching storage', () {
    final repository = _FakeVehicleExpenseRepository();
    expect(() => DeleteVehicleExpense(repository)(0), throwsArgumentError);
  });
}

class _FakeVehicleExpenseRepository implements VehicleExpenseRepository {
  final List<VehicleExpense> recorded = [];
  int _nextId = 1;

  @override
  Future<void> recordExpense(VehicleExpense expense) async {
    recorded.add(VehicleExpense(
      id: _nextId++,
      vehicleId: expense.vehicleId,
      category: expense.category,
      amount: expense.amount,
      date: expense.date,
      notes: expense.notes,
    ));
  }

  @override
  Future<List<VehicleExpense>> listForVehicle(int vehicleId) async =>
      recorded.where((expense) => expense.vehicleId == vehicleId).toList();

  @override
  Future<List<VehicleExpense>> listAll() async => List.unmodifiable(recorded);

  @override
  Future<void> deleteExpense(int expenseId) async {
    recorded.removeWhere((expense) => expense.id == expenseId);
  }
}
