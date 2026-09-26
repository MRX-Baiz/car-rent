import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/vehicle_model.dart';
import '../../data/repositories/vehicle_repository.dart';
import 'reminder_provider.dart';

final vehiclesProvider =
    AsyncNotifierProvider<VehicleNotifier, List<VehicleModel>>(
  VehicleNotifier.new,
);

class VehicleNotifier extends AsyncNotifier<List<VehicleModel>> {
  final VehicleRepository _repository = VehicleRepository.instance;

  @override
  FutureOr<List<VehicleModel>> build() async {
    return _repository.getAllVehicles();
  }

  Future<void> loadVehicles() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.getAllVehicles);
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    final current = state.value ?? const <VehicleModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final vehicleToInsert = vehicle.copyWith(
        createdAt: vehicle.createdAt,
        updatedAt: now,
      );
      final id = await _repository.insertVehicle(vehicleToInsert);
      final inserted = vehicleToInsert.copyWith(id: id);
      await ref.read(syncVehicleMaintenanceRemindersProvider)(id);
      return [inserted, ...current];
    });
  }

  Future<void> updateVehicle(VehicleModel vehicle) async {
    final current = state.value ?? const <VehicleModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final updatedVehicle = vehicle.copyWith(updatedAt: now);
      await _repository.updateVehicle(updatedVehicle);
      final id = updatedVehicle.id;
      if (id != null) {
        await ref.read(syncVehicleMaintenanceRemindersProvider)(id);
      }
      return current
          .map(
            (v) => v.id == updatedVehicle.id ? updatedVehicle : v,
          )
          .toList();
    });
  }

  Future<void> deleteVehicle(int id) async {
    final current = state.value ?? const <VehicleModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteVehicle(id);
      return current.where((v) => v.id != id).toList();
    });
  }

  Future<void> updateStatus(int id, String status) async {
    final current = state.value ?? const <VehicleModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.updateVehicleStatus(id, status);
      return current
          .map(
            (v) => v.id == id
                ? v.copyWith(
                    status: status,
                    updatedAt: DateTime.now(),
                  )
                : v,
          )
          .toList();
    });
  }
}
