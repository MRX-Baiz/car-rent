import 'dart:io';

import '../../domain/entities/inspection.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../models/inspection_model.dart';
import '../models/vehicle_model.dart';
import 'contract_repository.dart';
import 'inspection_repository.dart' as sqlite;
import 'vehicle_repository.dart';

/// Adapter that composes existing contract, vehicle, inspection and media
/// storage into the one workflow the inspection form needs.
class SqliteInspectionWorkflowRepository implements InspectionRepository {
  SqliteInspectionWorkflowRepository._internal();

  static final instance = SqliteInspectionWorkflowRepository._internal();

  @override
  Future<InspectionContext?> loadContext({
    required int contractId,
    required InspectionKind kind,
  }) async {
    final contract =
        await ContractRepository.instance.getContractById(contractId);
    if (contract == null) return null;
    final vehicle =
        await VehicleRepository.instance.getVehicleById(contract.vehicleId);
    if (vehicle == null || vehicle.id == null) return null;

    final departure = kind == InspectionKind.departure
        ? null
        : await sqlite.InspectionRepository.instance.get(
            contractId,
            InspectionKind.departure.storageValue,
          );
    return InspectionContext(
      contractNumber: contract.contractNumber,
      vehicle: _vehicle(vehicle),
      departureReading: departure == null ? null : _reading(departure),
    );
  }

  @override
  Future<void> save(InspectionDraft draft) async {
    await sqlite.InspectionRepository.instance.save(
      inspection: InspectionModel(
        contractId: draft.contractId,
        type: draft.kind.storageValue,
        mileage: draft.mileage,
        fuelLevel: draft.fuelLevel,
        conditionStatus: draft.conditionStatus,
        damageNotes: draft.damageNotes,
        extraCharges: draft.extraCharges,
        createdAt: draft.createdAt,
      ),
      photos: draft.photoSourcePaths.map(
        (kind, path) => MapEntry(kind, File(path)),
      ),
      signature: draft.signature,
    );

    final contract =
        await ContractRepository.instance.getContractById(draft.contractId);
    if (contract == null) return;
    final vehicle =
        await VehicleRepository.instance.getVehicleById(contract.vehicleId);
    if (vehicle == null) return;
    await VehicleRepository.instance.updateVehicle(
      vehicle.copyWith(
        currentMileage: draft.mileage,
        fuelLevel: draft.fuelLevel,
        conditionStatus: draft.conditionStatus,
        updatedAt: draft.createdAt,
      ),
    );
  }

  static InspectionReading _reading(InspectionModel inspection) {
    return InspectionReading(
      contractId: inspection.contractId,
      kind: InspectionKind.fromStorageValue(inspection.type),
      mileage: inspection.mileage,
      fuelLevel: inspection.fuelLevel,
      conditionStatus: inspection.conditionStatus,
      damageNotes: inspection.damageNotes,
      extraCharges: inspection.extraCharges,
      signaturePath: inspection.signaturePath,
      createdAt: inspection.createdAt,
    );
  }

  static InspectionVehicle _vehicle(VehicleModel vehicle) {
    return InspectionVehicle(
      id: vehicle.id!,
      brand: vehicle.brand,
      model: vehicle.model,
      registrationNumber: vehicle.registrationNumber,
      currentMileage: vehicle.currentMileage,
      fuelLevel: vehicle.fuelLevel,
      conditionStatus: vehicle.conditionStatus,
      imagePath: vehicle.imagePath,
      imageBytes: vehicle.imageBytes,
    );
  }
}
