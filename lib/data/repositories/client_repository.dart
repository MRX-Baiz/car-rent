import 'package:sqflite/sqflite.dart';

import '../../core/database/database_exception_extension.dart';
import '../../core/database/database_helper.dart';
import '../models/client_model.dart';

class ClientRepository {
  ClientRepository._internal();

  static final ClientRepository instance = ClientRepository._internal();

  DatabaseHelper get _dbHelper => DatabaseHelper.instance;

  Future<int?> _findExistingClientIdByCinOrLicense({
    required String cin,
    required String licenseNumber,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT id
FROM clients
WHERE (is_archived IS NULL OR is_archived = 0)
  AND (cin = ? OR license_number = ?)
LIMIT 1
''',
      [cin, licenseNumber],
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  Future<int?> _findExistingClientIdForUpdate({
    required int id,
    required String cin,
    required String licenseNumber,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT id
FROM clients
WHERE (is_archived IS NULL OR is_archived = 0)
  AND id != ?
  AND (cin = ? OR license_number = ?)
LIMIT 1
''',
      [id, cin, licenseNumber],
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  Future<List<ClientModel>> getAllClients() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'clients',
        where: 'is_archived IS NULL OR is_archived = 0',
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
        where:
            '(is_archived IS NULL OR is_archived = 0) AND (first_name LIKE ? OR last_name LIKE ? OR cin LIKE ?)',
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

      // Check for an ACTIVE (non-archived) duplicate first.
      final existingId = await _findExistingClientIdByCinOrLicense(
        cin: client.cin,
        licenseNumber: client.licenseNumber,
      );
      if (existingId != null) {
        throw Exception(
          'CIN ou numéro de permis déjà existant. Veuillez vérifier les informations.',
        );
      }

      // Free UNIQUE slots occupied by archived rows with the same CIN / license.
      // Strategy: try a hard delete first. If FK constraints prevent it (the
      // archived client is referenced by old contracts), anonymize the fields
      // instead so the unique slot is freed while the contract history survives.
      final archivedRows = await db.query(
        'clients',
        columns: ['id'],
        where: '(is_archived = 1) AND (cin = ? OR license_number = ?)',
        whereArgs: [client.cin, client.licenseNumber],
      );
      for (final row in archivedRows) {
        final archivedId = row['id'] as int;
        try {
          await db.delete(
            'clients',
            where: 'id = ?',
            whereArgs: [archivedId],
          );
        } on DatabaseException {
          // FK constraint: contracts still reference this client.
          // Anonymize CIN/license so the UNIQUE slot is freed.
          await db.update(
            'clients',
            {
              'cin': '_deleted_${archivedId}_${client.cin}',
              'license_number': '_deleted_${archivedId}_${client.licenseNumber}',
            },
            where: 'id = ?',
            whereArgs: [archivedId],
          );
        }
      }

      return await db.insert(
        'clients',
        client.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('license')) {
          throw Exception('Un client avec ce numéro de permis existe déjà.');
        }
        throw Exception('Un client avec ce CIN existe déjà.');
      }
      throw Exception('Failed to insert client: $e');
    } catch (e) {
      throw Exception('$e');
    }
  }

  Future<int> updateClient(ClientModel client) async {
    if (client.id == null) {
      throw ArgumentError('Client id is required for update');
    }
    try {
      final db = await _dbHelper.database;
      final existingId = await _findExistingClientIdForUpdate(
        id: client.id!,
        cin: client.cin,
        licenseNumber: client.licenseNumber,
      );
      if (existingId != null) {
        throw Exception(
          'CIN ou numéro de permis déjà existant. Veuillez vérifier les informations.',
        );
      }
      return await db.update(
        'clients',
        client.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [client.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('license')) {
          throw Exception('Un client avec ce numéro de permis existe déjà.');
        }
        throw Exception('Un client avec ce CIN existe déjà.');
      }
      throw Exception('Failed to update client: $e');
    } catch (e) {
      throw Exception('Failed to update client: $e');
    }
  }

  Future<int> deleteClient(int id) async {
    try {
      final db = await _dbHelper.database;

      // Soft delete: keep history for closed contracts/PDFs.
      return await db.update(
        'clients',
        {
          'is_archived': 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('foreign key') || msg.contains('constraint')) {
        throw Exception(
          'Impossible de supprimer ce client: il est utilisé dans un contrat.',
        );
      }
      throw Exception('Failed to delete client: $e');
    } catch (e) {
      throw Exception('Failed to delete client: $e');
    }
  }
}

