import 'package:sqflite/sqflite.dart';

import '../../core/database/database_exception_extension.dart';
import '../../core/database/database_helper.dart';
import '../models/client_model.dart';

class ClientRepository {
  ClientRepository._internal();

  static final ClientRepository instance = ClientRepository._internal();

  DatabaseHelper get _dbHelper => DatabaseHelper.instance;

  Future<List<ClientModel>> getAllClients() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'clients',
        orderBy: 'created_at DESC',
      );
      return result.map(ClientModel.fromMap).toList();
    } catch (e) {
      throw Exception('Failed to load clients: $e');
    }
  }

  Future<ClientModel?> getClientById(int id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'clients',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return ClientModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to load client: $e');
    }
  }

  Future<ClientModel?> getClientByCIN(String cin) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'clients',
        where: 'cin = ?',
        whereArgs: [cin],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return ClientModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to load client by CIN: $e');
    }
  }

  /// Search by partial name (first or last) or CIN.
  Future<List<ClientModel>> searchClients(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return getAllClients();
    }
    final pattern = '%$normalized%';
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'clients',
        where: 'first_name LIKE ? OR last_name LIKE ? OR cin LIKE ?',
        whereArgs: [pattern, pattern, pattern],
        orderBy: 'last_name COLLATE NOCASE ASC, first_name COLLATE NOCASE ASC',
      );
      return result.map(ClientModel.fromMap).toList();
    } catch (e) {
      throw Exception('Failed to search clients: $e');
    }
  }

  Future<int> insertClient(ClientModel client) async {
    try {
      final db = await _dbHelper.database;
      return await db.insert(
        'clients',
        client.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('A client with this CIN already exists.');
      }
      throw Exception('Failed to insert client: $e');
    } catch (e) {
      throw Exception('Failed to insert client: $e');
    }
  }

  Future<int> updateClient(ClientModel client) async {
    if (client.id == null) {
      throw ArgumentError('Client id is required for update');
    }
    try {
      final db = await _dbHelper.database;
      return await db.update(
        'clients',
        client.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [client.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('A client with this CIN already exists.');
      }
      throw Exception('Failed to update client: $e');
    } catch (e) {
      throw Exception('Failed to update client: $e');
    }
  }

  Future<int> deleteClient(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete(
        'clients',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete client: $e');
    }
  }
}

