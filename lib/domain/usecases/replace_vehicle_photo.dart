import '../entities/vehicle_photo.dart';
import '../repositories/vehicle_photo_repository.dart';

class ReplaceVehiclePhoto {
  const ReplaceVehiclePhoto(this._repository);

  final VehiclePhotoRepository _repository;

  Future<void> call({
    required int vehicleId,
    required VehiclePhotoKind kind,
    required String sourcePath,
    String? note,
  }) {
    if (vehicleId <= 0) throw ArgumentError.value(vehicleId, 'vehicleId');
    if (sourcePath.trim().isEmpty) {
      throw ArgumentError.value(sourcePath, 'sourcePath');
    }
    return _repository.replacePhoto(
      vehicleId: vehicleId,
      kind: kind,
      sourcePath: sourcePath,
      note: note,
    );
  }
}
