import '../../domain/entities/search_result.dart';
import '../../domain/repositories/agency_search_repository.dart';
import '../models/client_model.dart';
import '../models/contract_model.dart';
import '../models/vehicle_model.dart';
import 'client_repository.dart';
import 'contract_repository.dart';
import 'vehicle_repository.dart';

class SqliteAgencySearchRepository implements AgencySearchRepository {
  SqliteAgencySearchRepository._internal();

  static final instance = SqliteAgencySearchRepository._internal();

  @override
  Future<AgencySearchResults> search(String query) async {
    final results = await Future.wait([
      ClientRepository.instance.searchClients(query),
      VehicleRepository.instance.searchVehicles(query),
      ContractRepository.instance.searchContracts(query),
    ]);
    final clients = results[0] as List<ClientModel>;
    final vehicles = results[1] as List<VehicleModel>;
    final contracts = results[2] as List<ContractModel>;
    return AgencySearchResults(
      clients: [
        for (final client in clients)
          if (client.id != null)
            SearchResultItem(
              kind: SearchResultKind.client,
              id: client.id!,
              title: client.fullName,
              subtitle: client.cin,
            ),
      ],
      vehicles: [
        for (final vehicle in vehicles)
          if (vehicle.id != null)
            SearchResultItem(
              kind: SearchResultKind.vehicle,
              id: vehicle.id!,
              title: '${vehicle.brand} ${vehicle.model}',
              subtitle: vehicle.registrationNumber,
              status: vehicle.status,
            ),
      ],
      contracts: [
        for (final contract in contracts)
          if (contract.id != null)
            SearchResultItem(
              kind: SearchResultKind.contract,
              id: contract.id!,
              title: contract.contractNumber,
              subtitle: contract.displayStatus,
            ),
      ],
    );
  }
}
