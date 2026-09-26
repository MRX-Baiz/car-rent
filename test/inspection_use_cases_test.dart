import 'package:car_rent_manager/domain/entities/inspection.dart';
import 'package:car_rent_manager/domain/repositories/inspection_repository.dart';
import 'package:car_rent_manager/domain/usecases/load_inspection_context.dart';
import 'package:car_rent_manager/domain/usecases/save_inspection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspection use cases depend only on the workflow contract', () async {
    final repository = _FakeInspectionRepository();
    final save = SaveInspection(repository);
    final load = LoadInspectionContext(repository);
    final draft = InspectionDraft(
      contractId: 10,
      kind: InspectionKind.departure,
      mileage: 42000,
      fuelLevel: 75,
      conditionStatus: 'good',
      photoSourcePaths: const {'front': '/picker/front.jpg'},
      createdAt: DateTime(2026, 9, 26),
    );

    await save(draft);

    expect(repository.saved, same(draft));
    expect(
        (await load(contractId: 10, kind: InspectionKind.departure))
            ?.vehicle
            .id,
        4);
  });

  test('inspection rejects an impossible fuel level before storage', () {
    final draft = InspectionDraft(
      contractId: 1,
      kind: InspectionKind.departure,
      mileage: 0,
      fuelLevel: 101,
      conditionStatus: 'good',
      photoSourcePaths: const {},
      createdAt: DateTime(2026),
    );
    expect(() => SaveInspection(_FakeInspectionRepository())(draft),
        throwsArgumentError);
  });
}

class _FakeInspectionRepository implements InspectionRepository {
  InspectionDraft? saved;

  @override
  Future<InspectionContext?> loadContext({
    required int contractId,
    required InspectionKind kind,
  }) async {
    return const InspectionContext(
      contractNumber: 'CTR-1',
      vehicle: InspectionVehicle(
        id: 4,
        brand: 'Dacia',
        model: 'Duster',
        registrationNumber: '123-A-1',
        currentMileage: 42000,
        fuelLevel: 75,
        conditionStatus: 'good',
      ),
    );
  }

  @override
  Future<void> save(InspectionDraft draft) async => saved = draft;
}
