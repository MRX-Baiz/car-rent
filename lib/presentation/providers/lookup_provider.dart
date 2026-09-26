import 'package:flutter/widgets.dart';
import '../../core/localization/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chauffeur_model.dart';
import '../../data/models/client_model.dart';
import '../../data/models/contract_model.dart';
import '../../data/models/vehicle_model.dart';
import '../../data/repositories/chauffeur_repository.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/contract_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import 'contract_provider.dart';
import 'vehicle_provider.dart';

/// Names for the ids stored on contracts, so lists can say "Dacia Logan ·
/// Karim Alami" instead of "Véhicule #3 · Client #7".
///
/// Read straight from the repositories rather than through the clients
/// provider, whose state is replaced by search results while the clients
/// screen is filtering.
class Lookups {
  const Lookups({
    this.vehicles = const {},
    this.clients = const {},
    this.chauffeurs = const {},
  });

  final Map<int, VehicleModel> vehicles;
  final Map<int, ClientModel> clients;
  final Map<int, ChauffeurModel> chauffeurs;

  VehicleModel? vehicle(int? id) => id == null ? null : vehicles[id];
  ClientModel? client(int? id) => id == null ? null : clients[id];
  ChauffeurModel? chauffeur(int? id) => id == null ? null : chauffeurs[id];

  String vehicleNameFor(BuildContext context, int id) => vehicles[id] == null
      ? context.messages.vehicleNumber(id.toString()) : vehicleName(id);
  String clientNameFor(BuildContext context, int id) => clients[id]?.fullName ?? context.messages.clientNumber(id.toString());

  String vehicleName(int id) {
    final v = vehicles[id];
    return v == null ? 'Véhicule #$id' : '${v.brand} ${v.model}';
  }

  String clientName(int id) => clients[id]?.fullName ?? 'Client #$id';

  String contractTitle(ContractModel c) => vehicleName(c.vehicleId);
}

final lookupsProvider = FutureProvider.autoDispose<Lookups>((ref) async {
  // Re-read whenever contracts or vehicles change, so a new contract or a
  // renamed vehicle shows up without leaving the screen.
  ref.watch(contractsProvider);
  ref.watch(vehiclesProvider);

  final vehicles = await VehicleRepository.instance.getAllVehicles();
  final clients = await ClientRepository.instance.getAllClients();
  final chauffeurs = await ChauffeurRepository.instance.all();
  return Lookups(
    vehicles: {
      for (final v in vehicles)
        if (v.id != null) v.id!: v
    },
    clients: {
      for (final c in clients)
        if (c.id != null) c.id!: c
    },
    chauffeurs: {
      for (final c in chauffeurs)
        if (c.id != null) c.id!: c
    },
  );
});

final clientContractsProvider = FutureProvider.autoDispose
    .family<List<ContractModel>, int>((ref, clientId) {
  ref.watch(contractsProvider);
  return ContractRepository.instance.getContractsByClientId(clientId);
});

final vehicleContractsProvider = FutureProvider.autoDispose
    .family<List<ContractModel>, int>((ref, vehicleId) {
  ref.watch(contractsProvider);
  return ContractRepository.instance.getContractsByVehicleId(vehicleId);
});
