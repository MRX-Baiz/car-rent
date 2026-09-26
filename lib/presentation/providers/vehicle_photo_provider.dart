import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/vehicle_photo_repository.dart';
import '../../domain/entities/vehicle_photo.dart';
import '../../domain/repositories/vehicle_photo_repository.dart';
import '../../domain/usecases/load_vehicle_photos.dart';
import '../../domain/usecases/replace_vehicle_photo.dart';

final vehiclePhotoRepositoryProvider = Provider<VehiclePhotoRepository>((ref) {
  return SqliteVehiclePhotoRepository.instance;
});

final loadVehiclePhotosProvider = Provider<LoadVehiclePhotos>((ref) {
  return LoadVehiclePhotos(ref.watch(vehiclePhotoRepositoryProvider));
});

final replaceVehiclePhotoProvider = Provider<ReplaceVehiclePhoto>((ref) {
  return ReplaceVehiclePhoto(ref.watch(vehiclePhotoRepositoryProvider));
});

final vehiclePhotosProvider =
    FutureProvider.autoDispose.family<Map<VehiclePhotoKind, String>, int>(
  (ref, vehicleId) => ref.watch(loadVehiclePhotosProvider)(vehicleId),
);
