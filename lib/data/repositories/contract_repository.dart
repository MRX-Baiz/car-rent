import 'package:sqflite/sqflite.dart';

import '../../core/database/database_exception_extension.dart';
import '../../core/database/database_helper.dart';
import '../models/contract_model.dart';

class ContractRepository {
  ContractRepository._internal();

  static final ContractRepository instance = ContractRepository._internal();

  DatabaseHelper get _dbHelper => DatabaseHelper.instance;

  Future<List<ContractModel>> getAllContracts() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'contracts',
        orderBy: 'created_at DESC',
      );
      return result.map(ContractModel.fromMap).toList();
    } catch (e) {
      throw Exception('Failed to load contracts: $e');
    }
  }

  Future<ContractModel?> getContractById(int id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'contracts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return ContractModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to load contract: $e');
    }
  }

  Future<List<ContractModel>> getActiveContracts() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'contracts',
        where: 'status = ?',
        whereArgs: ['active'],
        orderBy: 'start_date DESC',
      );
      return result.map(ContractModel.fromMap).toList();
    } catch (e) {
      throw Exception('Failed to load active contracts: $e');
    }
  }

  Future<List<ContractModel>> getLateContracts() async {
    try {
      final db = await _dbHelper.database;
      final nowIso = DateTime.now().toIso8601String();
      // Late = active and expected_return_date < now
      final result = await db.query(
        'contracts',
        where: 'status = ? AND expected_return_date < ?',
        whereArgs: ['active', nowIso],
        orderBy: 'expected_return_date ASC',
      );
      return result.map(ContractModel.fromMap).toList();
    } catch (e) {
      throw Exception('Failed to load late contracts: $e');
    }
  }

  Future<List<ContractModel>> getContractsByClientId(int clientId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'contracts',
        where: 'primary_driver_id = ? OR secondary_driver_id = ?',
        whereArgs: [clientId, clientId],
        orderBy: 'start_date DESC',
      );
      return result.map(ContractModel.fromMap).toList();
    } catch (e) {
      throw Exception('Failed to load client contracts: $e');
    }
  }

  Future<List<ContractModel>> getContractsByVehicleId(int vehicleId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'contracts',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'start_date DESC',
      );
      return result.map(ContractModel.fromMap).toList();
    } catch (e) {
      throw Exception('Failed to load vehicle contracts: $e');
    }
  }

  Future<int> insertContract(ContractModel contract) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      // Check for existing active contract for the same vehicle.
      final existing = await txn.query(
        'contracts',
        columns: ['id'],
        where: 'vehicle_id = ? AND status = ?',
        whereArgs: [contract.vehicleId, 'active'],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw Exception('This vehicle already has an active contract.');
      }

      try {
        final id = await txn.insert(
          'contracts',
          contract.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        // Update vehicle status to 'rented'
        await txn.update(
          'vehicles',
          {
            'status': 'rented',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [contract.vehicleId],
        );

        return id;
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError()) {
          throw Exception('A contract with this number already exists.');
        }
        throw Exception('Failed to insert contract: $e');
      }
    });
  }

  Future<int> updateContract(ContractModel contract) async {
    if (contract.id == null) {
      throw ArgumentError('Contract id is required for update');
    }
    try {
      final db = await _dbHelper.database;
      return await db.update(
        'contracts',
        contract.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [contract.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('A contract with this number already exists.');
      }
      throw Exception('Failed to update contract: $e');
    } catch (e) {
      throw Exception('Failed to update contract: $e');
    }
  }

  Future<void> closeContract(int id, DateTime returnDate) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Load contract
      final rows = await txn.query(
        'contracts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw Exception('Contract not found');
      }
      final contract = ContractModel.fromMap(rows.first);

      // Update contract
      await txn.update(
        'contracts',
        {
          'status': 'completed',
          'actual_return_date': returnDate.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // Update vehicle status back to 'available'
      await txn.update(
        'vehicles',
        {
          'status': 'available',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [contract.vehicleId],
      );
    });
  }

  /// Generates the next contract number in the format:
  /// CTR-YYYYMMDD-0001
  Future<String> generateContractNumber() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final datePart =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'CTR-$datePart-';

    final result = await db.query(
      'contracts',
      columns: ['contract_number'],
      where: 'contract_number LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'contract_number DESC',
      limit: 1,
    );

    int nextSequence = 1;
    if (result.isNotEmpty) {
      final lastNumber = result.first['contract_number'] as String;
      final parts = lastNumber.split('-');
      if (parts.length == 3) {
        final seqStr = parts[2];
        final parsed = int.tryParse(seqStr);
        if (parsed != null) {
          nextSequence = parsed + 1;
        }
      }
    }

    final seqPart = nextSequence.toString().padLeft(4, '0');
    return '$prefix$seqPart';
  }

  Future<int> getActiveContractsCount() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM contracts WHERE status = ?',
        ['active'],
      );
      final dynamic raw = result.first['count'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return 0;
    } catch (e) {
      throw Exception('Failed to get active contracts count: $e');
    }
  }
}

