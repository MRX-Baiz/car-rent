import '../entities/vehicle_photo.dart';
import '../repositories/vehicle_photo_repository.dart';

class LoadVehiclePhotos {
  const LoadVehiclePhotos(this._repository);

  final VehiclePhotoRepository _repository;

  Future<Map<VehiclePhotoKind, String>> call(int vehicleId) {
    if (vehicleId <= 0) throw ArgumentError.value(vehicleId, 'vehicleId');
    return _repository.loadForVehicle(vehicleId);
  }
}
