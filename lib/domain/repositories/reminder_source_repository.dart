import '../entities/reminder_plans.dart';

/// The stored data reminders are derived from, read as plans.
abstract interface class ReminderSourceRepository {
  /// `null` once the contract no longer exists, e.g. after it was deleted.
  Future<ContractReminderPlan?> contractPlan(int contractId);

  Future<List<ContractReminderPlan>> allContractPlans();

  Future<VehicleMaintenancePlan?> vehiclePlan(int vehicleId);

  Future<List<VehicleMaintenancePlan>> allVehiclePlans();
}
