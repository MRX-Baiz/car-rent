import 'dart:io';
import 'dart:typed_data';
import '../../core/database/database_helper.dart';
import '../../core/storage/media_store.dart';
import '../models/inspection_model.dart';

class InspectionRepository {
  InspectionRepository._();
  static final instance = InspectionRepository._();
  Future<InspectionModel?> get(int contractId, String type) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('contract_inspections',
        where: 'contract_id = ? AND type = ?',
        whereArgs: [contractId, type],
        limit: 1);
    return rows.isEmpty ? null : InspectionModel.fromMap(rows.first);
  }

  Future<List<String>> photos(int inspectionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('inspection_photos',
        columns: ['path'],
        where: 'inspection_id = ?',
        whereArgs: [inspectionId]);
    return rows.map((r) => r['path'] as String).toList();
  }

  Future<void> save(
      {required InspectionModel inspection,
      required Map<String, File> photos,
      Uint8List? signature}) async {
    final storedPhotos = <String, String>{};
    for (final entry in photos.entries) {
      storedPhotos[entry.key] = await MediaStore.instance.save(entry.value,
          prefix: 'inspection_${inspection.type}_${entry.key}');
    }
    final signaturePath = signature == null
        ? null
        : await MediaStore.instance
            .saveBytes(signature, prefix: 'signature_${inspection.type}');
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final id = await txn.insert('contract_inspections',
          inspection.copyWithSignature(signaturePath).toMap()..remove('id'));
      for (final entry in storedPhotos.entries) {
        await txn.insert('inspection_photos', {
          'inspection_id': id,
          'kind': entry.key,
          'path': entry.value,
          'created_at': DateTime.now().toIso8601String()
        });
      }
    });
  }
}

extension on InspectionModel {
  InspectionModel copyWithSignature(String? value) => InspectionModel(
      id: id,
      contractId: contractId,
      type: type,
      mileage: mileage,
      fuelLevel: fuelLevel,
      conditionStatus: conditionStatus,
      damageNotes: damageNotes,
      extraCharges: extraCharges,
      signaturePath: value,
      createdAt: createdAt);
}
