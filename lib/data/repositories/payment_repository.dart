import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  PaymentRepository._internal();

  static final PaymentRepository instance = PaymentRepository._internal();

  DatabaseHelper get _dbHelper => DatabaseHelper.instance;

  Future<List<PaymentModel>> getPaymentsByContractId(int contractId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'payments',
        where: 'contract_id = ?',
        whereArgs: [contractId],
        orderBy: 'payment_date ASC',
      );
      return result.map(PaymentModel.fromMap).toList();
    } catch (e) {
      throw Exception('Failed to load payments: $e');
    }
  }

  Future<int> insertPayment(PaymentModel payment) async {
    try {
      final db = await _dbHelper.database;
      return await db.insert(
        'payments',
        payment.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      throw Exception('Failed to insert payment: $e');
    } catch (e) {
      throw Exception('Failed to insert payment: $e');
    }
  }

  Future<int> updatePayment(PaymentModel payment) async {
    if (payment.id == null) {
      throw ArgumentError('Payment id is required for update');
    }
    try {
      final db = await _dbHelper.database;
      return await db.update(
        'payments',
        payment.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [payment.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      throw Exception('Failed to update payment: $e');
    } catch (e) {
      throw Exception('Failed to update payment: $e');
    }
  }

  Future<int> deletePayment(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete(
        'payments',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete payment: $e');
    }
  }

  /// Returns the total amount paid for a specific contract.
  Future<double> getTotalPaidForContract(int contractId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT SUM(amount) AS total FROM payments WHERE contract_id = ?',
        [contractId],
      );
      final raw = result.first['total'];
      if (raw == null) return 0.0;
      if (raw is int) return raw.toDouble();
      if (raw is num) return raw.toDouble();
      return 0.0;
    } catch (e) {
      throw Exception('Failed to calculate total paid: $e');
    }
  }

  /// Returns the total revenue for a calendar month (based on payment_date).
  Future<double> getTotalRevenueForMonth(DateTime month) async {
    try {
      final db = await _dbHelper.database;
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);

      final result = await db.rawQuery(
        'SELECT SUM(amount) AS total FROM payments WHERE payment_date >= ? AND payment_date < ?',
        [start.toIso8601String(), end.toIso8601String()],
      );
      final raw = result.first['total'];
      if (raw == null) return 0.0;
      if (raw is int) return raw.toDouble();
      if (raw is num) return raw.toDouble();
      return 0.0;
    } catch (e) {
      throw Exception('Failed to calculate monthly revenue: $e');
    }
  }

  /// Returns daily revenue sums for each day in the range [start, end).
  Future<Map<DateTime, double>> getDailyRevenue(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT 
          strftime('%Y-%m-%d', payment_date) as day, 
          SUM(amount) as total 
        FROM payments 
        WHERE payment_date >= ? AND payment_date < ? 
        GROUP BY day 
        ORDER BY day ASC
        ''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final Map<DateTime, double> revenueMap = {};
      for (final row in result) {
        final dayStr = row['day'] as String;
        final total = (row['total'] as num).toDouble();
        revenueMap[DateTime.parse(dayStr)] = total;
      }
      return revenueMap;
    } catch (e) {
      throw Exception('Failed to fetch daily revenue: $e');
    }
  }
}

