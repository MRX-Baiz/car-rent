import '../entities/inspection.dart';

/// Inspection workflow storage, independent from SQLite and local media.
abstract interface class InspectionRepository {
  Future<InspectionContext?> loadContext({
    required int contractId,
    required InspectionKind kind,
  });

  Future<void> save(InspectionDraft draft);
}
