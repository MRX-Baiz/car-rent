import 'package:car_rent_manager/domain/entities/vehicle_photo.dart';
import 'package:car_rent_manager/domain/repositories/vehicle_photo_repository.dart';
import 'package:car_rent_manager/domain/usecases/load_vehicle_photos.dart';
import 'package:car_rent_manager/domain/usecases/replace_vehicle_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo use cases use the domain storage contract', () async {
    final repository = _FakeVehiclePhotoRepository();
    final replace = ReplaceVehiclePhoto(repository);
    final load = LoadVehiclePhotos(repository);

    await replace(
      vehicleId: 4,
      kind: VehiclePhotoKind.damage,
      sourcePath: '/picker/damage.jpg',
      note: 'Scratch on bumper',
    );

    expect((await load(4))[VehiclePhotoKind.damage], '/picker/damage.jpg');
    expect(repository.note, 'Scratch on bumper');
  });

  test('a photo source path must not be empty', () {
    expect(
      () => ReplaceVehiclePhoto(_FakeVehiclePhotoRepository())(
        vehicleId: 1,
        kind: VehiclePhotoKind.front,
        sourcePath: '',
      ),
      throwsArgumentError,
    );
  });
}

class _FakeVehiclePhotoRepository implements VehiclePhotoRepository {
  final Map<int, Map<VehiclePhotoKind, String>> _photos = {};
  String? note;

  @override
  Future<Map<VehiclePhotoKind, String>> loadForVehicle(int vehicleId) async {
    return Map.unmodifiable(_photos[vehicleId] ?? const {});
  }

  @override
  Future<void> replacePhoto({
    required int vehicleId,
    required VehiclePhotoKind kind,
    required String sourcePath,
    String? note,
  }) async {
    _photos.putIfAbsent(vehicleId, () => {})[kind] = sourcePath;
    this.note = note;
  }
}
