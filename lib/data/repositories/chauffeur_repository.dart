import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../models/chauffeur_model.dart';

class ChauffeurRepository {
  ChauffeurRepository._();
  static final instance = ChauffeurRepository._();
  Future<List<ChauffeurModel>> all() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('chauffeurs', orderBy: 'first_name, last_name');
    return rows.map(ChauffeurModel.fromMap).toList();
  }

  Future<int> insert(ChauffeurModel value) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert('chauffeurs', value.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> update(ChauffeurModel value) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('chauffeurs', value.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [value.id]);
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('chauffeurs', where: 'id = ?', whereArgs: [id]);
  }
}
