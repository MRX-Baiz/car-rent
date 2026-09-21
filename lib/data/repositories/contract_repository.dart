import 'package:sqflite/sqflite.dart';

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
      if (contract.chauffeurId != null) {
        final driver = await txn.query('chauffeurs',
            columns: ['status'],
            where: 'id = ?',
            whereArgs: [contract.chauffeurId],
            limit: 1);
        if (driver.isEmpty || driver.single['status'] != 'available')
          throw Exception('Ce chauffeur n’est pas disponible.');
      }

      try {
        final id = await txn.insert(
          'contracts',
          contract.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        // Record initial payment if any
        if (contract.amountPaid > 0) {
          final nowString = DateTime.now().toIso8601String();
          await txn.rawInsert(
            'INSERT INTO payments (contract_id, amount, payment_date, payment_method, created_at) VALUES (?, ?, ?, ?, ?)',
            [id, contract.amountPaid, nowString, 'cash', nowString],
          );
        }

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
        if (contract.chauffeurId != null) {
          await txn.update(
              'chauffeurs',
              {
                'status': 'assigned',
                'updated_at': DateTime.now().toIso8601String()
              },
              where: 'id = ?',
              whereArgs: [contract.chauffeurId]);
        }

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
      return await db.transaction((txn) async {
        final documents = await txn.query('contract_documents',
            where: 'contract_id = ?', whereArgs: [contract.id]);
        if (documents.isNotEmpty &&
            documents.single['terms_json'] != contract.signingTermsJson) {
          throw StateError('Le PDF de ce contrat est figé pour signature. '
              'Créez un nouveau contrat pour modifier les conditions.');
        }
        return txn.update(
          'contracts',
          contract.toMap()..remove('id'),
          where: 'id = ?',
          whereArgs: [contract.id],
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('A contract with this number already exists.');
      }
      throw Exception('Failed to update contract: $e');
    } catch (e) {
      throw Exception('Failed to update contract: $e');
    }
  }

  /// Atomically inserts a payment row AND increments amount_paid on the contract.
  Future<void> addPaymentAndUpdateContract(
      int contractId, double amount) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Insert payment record
      final now = DateTime.now().toIso8601String();
      await txn.rawInsert(
        'INSERT INTO payments (contract_id, amount, payment_date, payment_method, created_at) VALUES (?, ?, ?, ?, ?)',
        [contractId, amount, now, 'cash', now],
      );
      // Increment amount_paid on the contract
      await txn.rawUpdate(
        'UPDATE contracts SET amount_paid = amount_paid + ?, updated_at = ? WHERE id = ?',
        [amount, now, contractId],
      );
    });
  }

  Future<void> deleteContract(int id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'contracts',
        columns: ['vehicle_id', 'chauffeur_id', 'status'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      await txn.delete(
        'payments',
        where: 'contract_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'contracts',
        where: 'id = ?',
        whereArgs: [id],
      );

      // Deleting an active contract must free up the vehicle, otherwise it
      // stays 'rented' forever and can never be rented out again.
      if (rows.isNotEmpty && rows.first['status'] == 'active') {
        await txn.update(
          'vehicles',
          {
            'status': 'available',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [rows.first['vehicle_id']],
        );
        final chauffeurId = rows.first['chauffeur_id'] as int?;
        if (chauffeurId != null)
          await txn.update(
              'chauffeurs',
              {
                'status': 'available',
                'updated_at': DateTime.now().toIso8601String()
              },
              where: 'id = ?',
              whereArgs: [chauffeurId]);
      }
    });
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
      if (contract.chauffeurId != null)
        await txn.update(
            'chauffeurs',
            {
              'status': 'available',
              'updated_at': DateTime.now().toIso8601String()
            },
            where: 'id = ?',
            whereArgs: [contract.chauffeurId]);

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

  Future<List<ContractModel>> searchContracts(String query) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'contracts',
        where: 'contract_number LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'created_at DESC',
      );
      return result.map(ContractModel.fromMap).toList();
    } catch (e) {
      throw Exception('Failed to search contracts: $e');
    }
  }
}
