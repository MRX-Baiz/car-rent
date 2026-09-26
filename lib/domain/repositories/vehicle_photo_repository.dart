import '../entities/vehicle_photo.dart';

/// Photo storage needed by the vehicle record workflow.
///
/// Presentation supplies a source path rather than a [File], keeping file
/// copying and SQLite details in the data implementation.
abstract interface class VehiclePhotoRepository {
  Future<Map<VehiclePhotoKind, String>> loadForVehicle(int vehicleId);

  Future<void> replacePhoto({
    required int vehicleId,
    required VehiclePhotoKind kind,
    required String sourcePath,
    String? note,
  });
}
