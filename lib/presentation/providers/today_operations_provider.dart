import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mappers/today_operations_mapper.dart';
import '../../domain/entities/today_operations.dart';
import '../../domain/usecases/build_today_operations.dart';
import 'contract_provider.dart';
import 'vehicle_provider.dart';

final buildTodayOperationsProvider = Provider<BuildTodayOperations>((ref) {
  return const BuildTodayOperations();
});

/// Joins the existing contract and vehicle streams at the presentation
/// boundary, then hands only domain entities to the business use case.
final todayOperationsProvider =
    Provider<AsyncValue<TodayOperationsQueue>>((ref) {
  final contracts = ref.watch(contractsProvider);
  final vehicles = ref.watch(vehiclesProvider);

  if (contracts.hasError) {
    return AsyncValue.error(
      contracts.error!,
      contracts.stackTrace ?? StackTrace.current,
    );
  }
  if (vehicles.hasError) {
    return AsyncValue.error(
      vehicles.error!,
      vehicles.stackTrace ?? StackTrace.current,
    );
  }
  if (contracts.isLoading || vehicles.isLoading) {
    return const AsyncValue.loading();
  }

  final queue = ref.read(buildTodayOperationsProvider)(
    contracts: (contracts.value ?? const [])
        .map((contract) => contract.toOperationsContract())
        .whereType<OperationsContract>(),
    vehicles: (vehicles.value ?? const [])
        .map((vehicle) => vehicle.toOperationsVehicle())
        .whereType<OperationsVehicle>(),
  );
  return AsyncValue.data(queue);
});
