import 'package:sqflite/sqflite.dart';

import '../../core/database/database_exception_extension.dart';
import '../../core/database/database_helper.dart';
import '../models/vehicle_model.dart';

class VehicleRepository {
  VehicleRepository._internal();

  static final VehicleRepository instance = VehicleRepository._internal();

  DatabaseHelper get _dbHelper => DatabaseHelper.instance;

  Future<List<VehicleModel>> getAllVehicles() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'vehicles',
        orderBy: 'created_at DESC',
      );
      return result.map((e) => VehicleModel.fromMap(e)).toList();
    } catch (e, stackTrace) {
      print('DB_ERROR: Error loading vehicles: $e');
      print('DB_ERROR: Stacktrace: $stackTrace');
      throw Exception('Failed to load vehicles: $e');
    }
  }

  Future<VehicleModel?> getVehicleById(int id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'vehicles',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return VehicleModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to load vehicle: $e');
    }
  }

  Future<List<VehicleModel>> getVehiclesByStatus(String status) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'vehicles',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'created_at DESC',
      );
      return result.map((e) => VehicleModel.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Failed to load vehicles by status: $e');
    }
  }

  Future<int> insertVehicle(VehicleModel vehicle) async {
    try {
      final db = await _dbHelper.database;
      return await db.insert(
        'vehicles',
        vehicle.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      // Surface unique constraint violations clearly; UI can localize messages.
      if (e.isUniqueConstraintError()) {
        throw Exception('A vehicle with this registration number already exists.');
      }
      throw Exception('Failed to insert vehicle: $e');
    } catch (e) {
      throw Exception('Failed to insert vehicle: $e');
    }
  }

  Future<int> updateVehicle(VehicleModel vehicle) async {
    if (vehicle.id == null) {
      throw ArgumentError('Vehicle id is required for update');
    }
    try {
      final db = await _dbHelper.database;
      return await db.update(
        'vehicles',
        vehicle.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [vehicle.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('A vehicle with this registration number already exists.');
      }
      throw Exception('Failed to update vehicle: $e');
    } catch (e) {
      throw Exception('Failed to update vehicle: $e');
    }
  }

  Future<int> deleteVehicle(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete(
        'vehicles',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete vehicle: $e');
    }
  }

  Future<void> updateVehicleStatus(int id, String status) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'vehicles',
        {
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to update vehicle status: $e');
    }
  }

  Future<int> getAvailableVehiclesCount() async {
      try {
        final db = await _dbHelper.database;
        final result = await db.rawQuery(
          'SELECT COUNT(*) AS count FROM vehicles WHERE status = ?',
          ['available'],
        );
        final value = result.first['count'] as int? ?? (result.first['count'] as num).toInt();
        return value;
      } catch (e) {
        throw Exception('Failed to get available vehicles count: $e');
      }
  }

  Future<int> getRentedVehiclesCount() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM vehicles WHERE status = ?',
        ['rented'],
      );
      final value = result.first['count'] as int? ?? (result.first['count'] as num).toInt();
      return value;
    } catch (e) {
      throw Exception('Failed to get rented vehicles count: $e');
    }
  }

  Future<List<VehicleModel>> searchVehicles(String query) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'vehicles',
        where: 'brand LIKE ? OR model LIKE ? OR registration_number LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'brand ASC',
      );
      return result.map((e) => VehicleModel.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Failed to search vehicles: $e');
    }
  }
}

