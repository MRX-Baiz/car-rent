import '../../core/database/database_helper.dart';
import '../../domain/entities/vehicle_expense.dart';
import '../../domain/repositories/vehicle_expense_repository.dart';
import '../models/vehicle_expense_model.dart';

/// SQLite implementation of [VehicleExpenseRepository]. A brand-new table
/// with no legacy repository to delegate to, so this reads/writes it
/// directly — the same shape as [SqliteVehiclePhotoRepository].
class SqliteVehicleExpenseRepository implements VehicleExpenseRepository {
  SqliteVehicleExpenseRepository._();

  static final instance = SqliteVehicleExpenseRepository._();

  @override
  Future<void> recordExpense(VehicleExpense expense) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'vehicle_expenses',
      VehicleExpenseModel(
        vehicleId: expense.vehicleId,
        category: expense.category.storageValue,
        amount: expense.amount,
        expenseDate: expense.date,
        notes: expense.notes,
        createdAt: DateTime.now(),
      ).toMap()
        ..remove('id'),
    );
  }

  @override
  Future<List<VehicleExpense>> listForVehicle(int vehicleId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'vehicle_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'expense_date DESC',
    );
    return rows.map(_toEntity).whereType<VehicleExpense>().toList();
  }

  @override
  Future<List<VehicleExpense>> listAll() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('vehicle_expenses', orderBy: 'expense_date DESC');
    return rows.map(_toEntity).whereType<VehicleExpense>().toList();
  }

  @override
  Future<void> deleteExpense(int expenseId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('vehicle_expenses', where: 'id = ?', whereArgs: [expenseId]);
  }

  /// A category string that predates a new enum value would otherwise crash
  /// every report; skip the row instead, same as an unknown photo kind.
  static VehicleExpense? _toEntity(Map<String, dynamic> row) {
    final model = VehicleExpenseModel.fromMap(row);
    final category = VehicleExpenseCategory.fromStorageValue(model.category);
    if (category == null) return null;
    return VehicleExpense(
      id: model.id,
      vehicleId: model.vehicleId,
      category: category,
      amount: model.amount,
      date: model.expenseDate,
      notes: model.notes,
    );
  }
}
