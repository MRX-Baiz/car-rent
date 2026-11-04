import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mappers/vehicle_profitability_mapper.dart';
import '../../data/repositories/vehicle_expense_repository.dart';
import '../../domain/entities/vehicle_expense.dart';
import '../../domain/entities/vehicle_profitability.dart';
import '../../domain/repositories/vehicle_expense_repository.dart';
import '../../domain/usecases/compute_vehicle_profitability.dart';
import '../../domain/usecases/delete_vehicle_expense.dart';
import '../../domain/usecases/list_vehicle_expenses.dart';
import '../../domain/usecases/record_vehicle_expense.dart';
import 'contract_provider.dart';
import 'vehicle_provider.dart';

final vehicleExpenseRepositoryProvider =
    Provider<VehicleExpenseRepository>((ref) {
  return SqliteVehicleExpenseRepository.instance;
});

final recordVehicleExpenseProvider = Provider<RecordVehicleExpense>((ref) {
  return RecordVehicleExpense(ref.watch(vehicleExpenseRepositoryProvider));
});

final deleteVehicleExpenseProvider = Provider<DeleteVehicleExpense>((ref) {
  return DeleteVehicleExpense(ref.watch(vehicleExpenseRepositoryProvider));
});

final listVehicleExpensesProvider = Provider<ListVehicleExpenses>((ref) {
  return ListVehicleExpenses(ref.watch(vehicleExpenseRepositoryProvider));
});

/// Itemized history for one vehicle's "add an expense" list.
final vehicleExpensesProvider =
    FutureProvider.autoDispose.family<List<VehicleExpense>, int>(
  (ref, vehicleId) => ref.watch(listVehicleExpensesProvider)(vehicleId),
);

/// Every expense across the fleet, for the profitability report — one query
/// rather than one per vehicle.
final allVehicleExpensesProvider =
    FutureProvider.autoDispose<List<VehicleExpense>>((ref) {
  return ref.watch(vehicleExpenseRepositoryProvider).listAll();
});

final computeVehicleProfitabilityProvider =
    Provider<ComputeVehicleProfitability>((ref) {
  return const ComputeVehicleProfitability();
});

/// Joins the existing contract/vehicle streams with this vehicle's expenses
/// at the presentation boundary, then hands only domain entities to the pure
/// use case — the same shape `todayOperationsProvider` already uses, so
/// contracts already loaded elsewhere are never read from storage twice.
final vehicleProfitabilityProvider =
    Provider.family<AsyncValue<VehicleProfitability>, int>((ref, vehicleId) {
  final contracts = ref.watch(contractsProvider);
  final vehicles = ref.watch(vehiclesProvider);
  final expenses = ref.watch(vehicleExpensesProvider(vehicleId));

  for (final async in [contracts, vehicles, expenses]) {
    if (async.hasError) {
      return AsyncValue.error(async.error!, async.stackTrace ?? StackTrace.current);
    }
  }
  if (contracts.isLoading || vehicles.isLoading || expenses.isLoading) {
    return const AsyncValue.loading();
  }

  final vehicle = (vehicles.value ?? const [])
      .where((item) => item.id == vehicleId)
      .firstOrNull;
  if (vehicle == null) {
    return AsyncValue.error(
      StateError('Vehicle $vehicleId not found'),
      StackTrace.current,
    );
  }

  final result = ref.read(computeVehicleProfitabilityProvider)(
    vehicleId: vehicleId,
    contracts:
        (contracts.value ?? const []).map((c) => c.toProfitabilityContract()),
    expenses: expenses.value ?? const [],
    addedAt: vehicle.createdAt,
  );
  return AsyncValue.data(result);
});

/// The same computation across every vehicle, sorted by net profit, for the
/// fleet-wide report.
final fleetProfitabilityProvider =
    Provider<AsyncValue<List<VehicleProfitability>>>((ref) {
  final contracts = ref.watch(contractsProvider);
  final vehicles = ref.watch(vehiclesProvider);
  final expenses = ref.watch(allVehicleExpensesProvider);

  for (final async in [contracts, vehicles, expenses]) {
    if (async.hasError) {
      return AsyncValue.error(async.error!, async.stackTrace ?? StackTrace.current);
    }
  }
  if (contracts.isLoading || vehicles.isLoading || expenses.isLoading) {
    return const AsyncValue.loading();
  }

  final profitabilityContracts =
      (contracts.value ?? const []).map((c) => c.toProfitabilityContract());
  final allExpenses = expenses.value ?? const <VehicleExpense>[];
  final compute = ref.read(computeVehicleProfitabilityProvider);

  final results = [
    for (final vehicle in vehicles.value ?? const [])
      if (vehicle.id != null)
        compute(
          vehicleId: vehicle.id!,
          contracts: profitabilityContracts,
          expenses: allExpenses,
          addedAt: vehicle.createdAt,
        ),
  ]..sort((a, b) => b.netProfit.compareTo(a.netProfit));

  return AsyncValue.data(results);
});
