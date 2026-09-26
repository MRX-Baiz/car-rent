import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/inspection_workflow_repository.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../../domain/usecases/load_inspection_context.dart';
import '../../domain/usecases/save_inspection.dart';

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  return SqliteInspectionWorkflowRepository.instance;
});

final loadInspectionContextProvider = Provider<LoadInspectionContext>((ref) {
  return LoadInspectionContext(ref.watch(inspectionRepositoryProvider));
});

final saveInspectionProvider = Provider<SaveInspection>((ref) {
  return SaveInspection(ref.watch(inspectionRepositoryProvider));
});
