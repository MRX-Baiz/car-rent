import '../entities/inspection.dart';
import '../repositories/inspection_repository.dart';

class LoadInspectionContext {
  const LoadInspectionContext(this._repository);

  final InspectionRepository _repository;

  Future<InspectionContext?> call({
    required int contractId,
    required InspectionKind kind,
  }) {
    if (contractId <= 0) throw ArgumentError.value(contractId, 'contractId');
    return _repository.loadContext(contractId: contractId, kind: kind);
  }
}
