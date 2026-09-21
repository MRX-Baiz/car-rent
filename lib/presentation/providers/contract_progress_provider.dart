import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contracts/contract_signing_service.dart';
import '../../data/models/contract_document.dart';
import '../../data/models/inspection_model.dart';
import '../../data/repositories/inspection_repository.dart';

/// Where a rental stands in its lifecycle: the inputs to the checklist at the
/// top of the contract page. Read-only; the actions themselves live in the
/// inspection screens and the signature card.
class ContractProgress {
  const ContractProgress({this.departure, this.returned, this.document});

  final InspectionModel? departure;
  final InspectionModel? returned;
  final ContractDocument? document;

  bool get departureDone => departure != null;
  bool get returnDone => returned != null;
  bool get signed => document?.isSigned == true;
}

final contractProgressProvider = FutureProvider.autoDispose
    .family<ContractProgress, int>((ref, contractId) async {
  final inspections = InspectionRepository.instance;
  return ContractProgress(
    departure: await inspections.get(contractId, 'departure'),
    returned: await inspections.get(contractId, 'return'),
    document: await ContractSigningService.instance.getDocument(contractId),
  );
});
