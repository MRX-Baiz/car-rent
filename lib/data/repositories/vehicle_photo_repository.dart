import 'dart:io';
import '../../core/database/database_helper.dart';
import '../../core/storage/media_store.dart';

class VehiclePhotoRepository {
  VehiclePhotoRepository._();
  static final instance = VehiclePhotoRepository._();
  Future<Map<String, String>> get(int vehicleId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('vehicle_photos',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'created_at DESC');
    final result = <String, String>{};
    for (final row in rows) {
      result.putIfAbsent(row['kind'] as String, () => row['path'] as String);
    }
    return result;
  }

  Future<void> save(int vehicleId, String kind, File file,
      {String? note}) async {
    final path = await MediaStore.instance.save(file, prefix: 'vehicle_$kind');
    final db = await DatabaseHelper.instance.database;
    await db.transaction((t) async {
      await t.delete('vehicle_photos',
          where: 'vehicle_id = ? AND kind = ?', whereArgs: [vehicleId, kind]);
      await t.insert('vehicle_photos', {
        'vehicle_id': vehicleId,
        'kind': kind,
        'path': path,
        'note': note,
        'created_at': DateTime.now().toIso8601String()
      });
    });
  }
}
