import 'dart:io';

import '../../core/database/database_helper.dart';
import '../../core/storage/media_store.dart';
import '../../domain/entities/vehicle_photo.dart';
import '../../domain/repositories/vehicle_photo_repository.dart';

/// SQLite and local-media implementation of [VehiclePhotoRepository].
class SqliteVehiclePhotoRepository implements VehiclePhotoRepository {
  SqliteVehiclePhotoRepository._();
  static final instance = SqliteVehiclePhotoRepository._();

  @override
  Future<Map<VehiclePhotoKind, String>> loadForVehicle(int vehicleId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('vehicle_photos',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'created_at DESC');
    final result = <VehiclePhotoKind, String>{};
    for (final row in rows) {
      final kind = VehiclePhotoKind.fromStorageValue(row['kind'] as String);
      if (kind != null) {
        result.putIfAbsent(kind, () => row['path'] as String);
      }
    }
    return result;
  }

  @override
  Future<void> replacePhoto({
    required int vehicleId,
    required VehiclePhotoKind kind,
    required String sourcePath,
    String? note,
  }) async {
    final path = await MediaStore.instance.save(
      File(sourcePath),
      prefix: 'vehicle_${kind.storageValue}',
    );
    final db = await DatabaseHelper.instance.database;
    await db.transaction((t) async {
      await t.delete('vehicle_photos',
          where: 'vehicle_id = ? AND kind = ?',
          whereArgs: [vehicleId, kind.storageValue]);
      await t.insert('vehicle_photos', {
        'vehicle_id': vehicleId,
        'kind': kind.storageValue,
        'path': path,
        'note': note,
        'created_at': DateTime.now().toIso8601String()
      });
    });
  }
}
