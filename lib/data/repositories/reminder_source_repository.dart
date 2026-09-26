import '../../domain/entities/reminder_plans.dart';
import '../../domain/repositories/reminder_source_repository.dart';
import '../models/contract_model.dart';
import '../models/vehicle_model.dart';
import 'contract_repository.dart';
import 'vehicle_repository.dart';

/// Reads contracts and vehicles from SQLite and shapes them into the plans
/// the reminder rules work with.
class SqliteReminderSourceRepository implements ReminderSourceRepository {
  SqliteReminderSourceRepository._();

  static final instance = SqliteReminderSourceRepository._();

  static const _unknownPlate = 'inconnu';

  @override
  Future<ContractReminderPlan?> contractPlan(int contractId) async {
    final contract =
        await ContractRepository.instance.getContractById(contractId);
    if (contract == null) return null;
    final vehicle =
        await VehicleRepository.instance.getVehicleById(contract.vehicleId);
    return _contractPlan(contract, vehicle);
  }

  @override
  Future<List<ContractReminderPlan>> allContractPlans() async {
    final contracts = await ContractRepository.instance.getAllContracts();
    final vehicles = {
      for (final vehicle in await VehicleRepository.instance.getAllVehicles())
        if (vehicle.id != null) vehicle.id!: vehicle,
    };
    return [
      for (final contract in contracts)
        if (contract.id != null)
          _contractPlan(contract, vehicles[contract.vehicleId]),
    ];
  }

  @override
  Future<VehicleMaintenancePlan?> vehiclePlan(int vehicleId) async {
    final vehicle = await VehicleRepository.instance.getVehicleById(vehicleId);
    return vehicle?.id == null ? null : _vehiclePlan(vehicle!);
  }

  @override
  Future<List<VehicleMaintenancePlan>> allVehiclePlans() async {
    final vehicles = await VehicleRepository.instance.getAllVehicles();
    return [
      for (final vehicle in vehicles)
        if (vehicle.id != null) _vehiclePlan(vehicle),
    ];
  }

  static ContractReminderPlan _contractPlan(
    ContractModel contract,
    VehicleModel? vehicle,
  ) {
    return ContractReminderPlan(
      contractId: contract.id!,
      isActive: contract.status == 'active',
      registrationNumber: vehicle?.registrationNumber ?? _unknownPlate,
      startDate: contract.startDate,
      expectedReturnDate: contract.expectedReturnDate,
      remainingAmount: contract.remainingAmount,
    );
  }

  static VehicleMaintenancePlan _vehiclePlan(VehicleModel vehicle) {
    return VehicleMaintenancePlan(
      vehicleId: vehicle.id!,
      registrationNumber: vehicle.registrationNumber,
      currentMileage: vehicle.currentMileage,
      insuranceExpiryDate: vehicle.insuranceExpiryDate,
      technicalInspectionExpiryDate: vehicle.technicalInspectionExpiryDate,
      vignetteDueDate: vehicle.vignetteDueDate,
      oilChangeDueDate: vehicle.oilChangeDueDate,
      oilChangeDueMileage: vehicle.oilChangeDueMileage,
      distributionDueDate: vehicle.distributionDueDate,
      distributionDueMileage: vehicle.distributionDueMileage,
    );
  }
}
