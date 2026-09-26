import '../entities/inspection.dart';
import '../repositories/inspection_repository.dart';

class SaveInspection {
  const SaveInspection(this._repository);

  final InspectionRepository _repository;

  Future<void> call(InspectionDraft draft) {
    if (draft.contractId <= 0) {
      throw ArgumentError.value(draft.contractId, 'contractId');
    }
    if (draft.mileage < 0) throw ArgumentError.value(draft.mileage, 'mileage');
    if (draft.fuelLevel < 0 || draft.fuelLevel > 100) {
      throw ArgumentError.value(draft.fuelLevel, 'fuelLevel');
    }
    return _repository.save(draft);
  }
}
