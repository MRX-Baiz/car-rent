import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mappers/client_history_mapper.dart';
import '../../data/models/contract_model.dart';
import '../../data/models/inspection_model.dart';
import '../../data/repositories/inspection_repository.dart';
import '../../domain/entities/client_history.dart';
import '../../domain/usecases/compute_client_history.dart';
import 'lookup_provider.dart';

/// Every inspection recorded against this client's contracts, for the
/// damage-incident count — one query, not one per contract.
final clientInspectionsProvider =
    FutureProvider.autoDispose.family<List<InspectionModel>, int>(
  (ref, clientId) async {
    final contracts = await ref.watch(clientContractsProvider(clientId).future);
    final contractIds = [
      for (final contract in contracts)
        if (contract.id != null) contract.id!,
    ];
    return InspectionRepository.instance.listByContractIds(contractIds);
  },
);

final computeClientHistoryProvider = Provider<ComputeClientHistory>((ref) {
  return const ComputeClientHistory();
});

/// Joins the client's already-loaded contracts with their inspections at the
/// presentation boundary, then hands only domain entities to the pure use
/// case — the same shape `vehicleProfitabilityProvider` uses.
final clientHistoryProvider =
    Provider.family<AsyncValue<ClientHistorySummary>, int>((ref, clientId) {
  final contracts = ref.watch(clientContractsProvider(clientId));
  final inspections = ref.watch(clientInspectionsProvider(clientId));

  for (final async in [contracts, inspections]) {
    if (async.hasError) {
      return AsyncValue.error(
          async.error!, async.stackTrace ?? StackTrace.current);
    }
  }
  if (contracts.isLoading || inspections.isLoading) {
    return const AsyncValue.loading();
  }

  final damagedContractIds = <int>{
    for (final inspection in inspections.value ?? const <InspectionModel>[])
      if (inspection.damageNotes?.isNotEmpty == true ||
          inspection.extraCharges > 0 ||
          inspection.conditionStatus != 'good')
        inspection.contractId,
  };

  final List<ContractModel> contractList =
      contracts.value ?? const <ContractModel>[];
  final List<ClientRentalRecord?> mapped = [
    for (final ContractModel contract in contractList)
      contract.toClientRentalRecord(
        hadDamage: damagedContractIds.contains(contract.id),
      ),
  ];
  final Iterable<ClientRentalRecord> rentals =
      mapped.whereType<ClientRentalRecord>();

  final result = ref.read(computeClientHistoryProvider)(
    clientId: clientId,
    rentals: rentals,
  );
  return AsyncValue.data(result);
});
