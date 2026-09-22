import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:car_rent_manager/core/database/database_helper.dart';
import 'package:car_rent_manager/data/models/chauffeur_model.dart';
import 'package:car_rent_manager/data/models/client_model.dart';
import 'package:car_rent_manager/data/models/contract_model.dart';
import 'package:car_rent_manager/data/models/vehicle_model.dart';
import 'package:car_rent_manager/data/repositories/chauffeur_repository.dart';
import 'package:car_rent_manager/data/repositories/client_repository.dart';
import 'package:car_rent_manager/data/repositories/contract_repository.dart';
import 'package:car_rent_manager/data/repositories/vehicle_repository.dart';

/// [ContractRepository.updateContract] is what lets an operator fix a
/// contract created by mistake (wrong vehicle, wrong client, wrong dates)
/// without waiting for the rental period to end and without touching a
/// contract that already has a PDF prepared for it. These tests exercise the
/// guarantees that make reassigning the vehicle/chauffeur on an *active*
/// contract safe: the same double-booking and availability checks
/// [ContractRepository.insertContract] already applies to a new contract, and
/// the vehicle/chauffeur status bookkeeping staying correct either way.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;

  setUp(() async {
    final dir = await databaseFactory.getDatabasesPath();
    dbPath = p.join(dir, 'car_rent_manager.db');
    await databaseFactory.deleteDatabase(dbPath);
    // Forces a fresh create, so every test starts from a clean schema.
    await DatabaseHelper.instance.database;
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    await databaseFactory.deleteDatabase(dbPath);
  });

  final now = DateTime(2026, 9, 1);

  Future<VehicleModel> makeVehicle(String plate) async {
    final id = await VehicleRepository.instance.insertVehicle(VehicleModel(
      brand: 'Dacia',
      model: 'Logan',
      registrationNumber: plate,
      year: 2022,
      status: 'available',
      createdAt: now,
      updatedAt: now,
    ));
    return (await VehicleRepository.instance.getVehicleById(id))!;
  }

  Future<ClientModel> makeClient(String cin) async {
    final id = await ClientRepository.instance.insertClient(ClientModel(
      firstName: 'Karim',
      lastName: 'Alami',
      cin: cin,
      licenseNumber: '33/$cin',
      phone: '0600000000',
      createdAt: now,
      updatedAt: now,
    ));
    return (await ClientRepository.instance.getClientById(id))!;
  }

  Future<ChauffeurModel> makeChauffeur(String cin,
      {String status = 'available'}) async {
    final id = await ChauffeurRepository.instance.insert(ChauffeurModel(
      firstName: 'Youssef',
      lastName: 'Bennani',
      cin: cin,
      licenseNumber: '12/$cin',
      phone: '0611111111',
      hourlyRate: 50,
      status: status,
      createdAt: now,
      updatedAt: now,
    ));
    final all = await ChauffeurRepository.instance.all();
    return all.firstWhere((c) => c.id == id);
  }

  ContractModel draft({
    required int vehicleId,
    required int clientId,
    int? chauffeurId,
    double totalPrice = 500,
    String status = 'active',
  }) =>
      ContractModel(
        contractNumber: 'CTR-TEST-${vehicleId}_$clientId',
        vehicleId: vehicleId,
        primaryDriverId: clientId,
        chauffeurId: chauffeurId,
        startDate: now,
        expectedReturnDate: now.add(const Duration(days: 2)),
        totalPrice: totalPrice,
        amountPaid: 0,
        status: status,
        createdAt: now,
        updatedAt: now,
      );

  test('creating a contract marks its vehicle rented', () async {
    final vehicle = await makeVehicle('AAA-1');
    final client = await makeClient('C001');
    await ContractRepository.instance
        .insertContract(draft(vehicleId: vehicle.id!, clientId: client.id!));

    final reloaded =
        await VehicleRepository.instance.getVehicleById(vehicle.id!);
    expect(reloaded!.status, 'rented');
  });

  test(
      'editing an active contract onto a different vehicle frees the old one '
      'and books the new one', () async {
    final vehicleA = await makeVehicle('AAA-2');
    final vehicleB = await makeVehicle('BBB-2');
    final client = await makeClient('C002');
    final id = await ContractRepository.instance
        .insertContract(draft(vehicleId: vehicleA.id!, clientId: client.id!));
    final contract = (await ContractRepository.instance.getContractById(id))!;

    await ContractRepository.instance
        .updateContract(contract.copyWith(vehicleId: vehicleB.id));

    final a = await VehicleRepository.instance.getVehicleById(vehicleA.id!);
    final b = await VehicleRepository.instance.getVehicleById(vehicleB.id!);
    expect(a!.status, 'available',
        reason: 'the mistakenly-assigned vehicle must come free again');
    expect(b!.status, 'rented');
  });

  test(
      'editing onto a vehicle that already has its own active contract is '
      'refused, and nothing is left half-changed', () async {
    final vehicleA = await makeVehicle('AAA-3');
    final vehicleB = await makeVehicle('BBB-3');
    final client1 = await makeClient('C003');
    final client2 = await makeClient('C004');
    final id1 = await ContractRepository.instance
        .insertContract(draft(vehicleId: vehicleA.id!, clientId: client1.id!));
    await ContractRepository.instance
        .insertContract(draft(vehicleId: vehicleB.id!, clientId: client2.id!));
    final contract1 = (await ContractRepository.instance.getContractById(id1))!;

    await expectLater(
      ContractRepository.instance
          .updateContract(contract1.copyWith(vehicleId: vehicleB.id)),
      throwsA(isA<Exception>()),
    );

    // Rolled back: both vehicles keep their original assignment.
    final a = await VehicleRepository.instance.getVehicleById(vehicleA.id!);
    final b = await VehicleRepository.instance.getVehicleById(vehicleB.id!);
    expect(a!.status, 'rented');
    expect(b!.status, 'rented');
    final unchanged = (await ContractRepository.instance.getContractById(id1))!;
    expect(unchanged.vehicleId, vehicleA.id);
  });

  test('editing onto a chauffeur who is already assigned elsewhere is refused',
      () async {
    final vehicle = await makeVehicle('AAA-4');
    final client = await makeClient('C005');
    final busyChauffeur = await makeChauffeur('CH001', status: 'assigned');
    final id = await ContractRepository.instance
        .insertContract(draft(vehicleId: vehicle.id!, clientId: client.id!));
    final contract = (await ContractRepository.instance.getContractById(id))!;

    await expectLater(
      ContractRepository.instance
          .updateContract(contract.copyWith(chauffeurId: busyChauffeur.id)),
      throwsA(isA<Exception>()),
    );
  });

  test('assigning a free chauffeur while editing marks them assigned',
      () async {
    final vehicle = await makeVehicle('AAA-5');
    final client = await makeClient('C006');
    final chauffeur = await makeChauffeur('CH002');
    final id = await ContractRepository.instance
        .insertContract(draft(vehicleId: vehicle.id!, clientId: client.id!));
    final contract = (await ContractRepository.instance.getContractById(id))!;

    await ContractRepository.instance
        .updateContract(contract.copyWith(chauffeurId: chauffeur.id));

    final all = await ChauffeurRepository.instance.all();
    final reloaded = all.firstWhere((c) => c.id == chauffeur.id);
    expect(reloaded.status, 'assigned');
  });

  test('deleting an active contract frees its vehicle', () async {
    final vehicle = await makeVehicle('AAA-6');
    final client = await makeClient('C007');
    final id = await ContractRepository.instance
        .insertContract(draft(vehicleId: vehicle.id!, clientId: client.id!));

    await ContractRepository.instance.deleteContract(id);

    final reloaded =
        await VehicleRepository.instance.getVehicleById(vehicle.id!);
    expect(reloaded!.status, 'available');
    expect(await ContractRepository.instance.getContractById(id), isNull);
  });
}
