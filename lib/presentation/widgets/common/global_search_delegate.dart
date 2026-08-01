import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/contract_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../widgets/common/status_badge.dart';

class GlobalSearchDelegate extends SearchDelegate {
  final WidgetRef ref;

  GlobalSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) {
      return const Center(child: Text('Tapez au moins 2 caractères...'));
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return FutureBuilder(
      future: Future.wait<dynamic>([
        ClientRepository.instance.searchClients(query),
        VehicleRepository.instance.searchVehicles(query),
        ContractRepository.instance.searchContracts(query),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }

        final clients = (snapshot.data?[0] as List<ClientModel>?) ?? [];
        final vehicles = (snapshot.data?[1] as List<VehicleModel>?) ?? [];
        final contracts = (snapshot.data?[2] as List<ContractModel>?) ?? [];

        if (clients.isEmpty && vehicles.isEmpty && contracts.isEmpty) {
          return const Center(child: Text('Aucun résultat trouvé.'));
        }

        return ListView(
          children: [
            if (clients.isNotEmpty) ...[
              _buildSectionHeader('Clients'),
              ...clients.map((c) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(c.fullName),
                    subtitle: Text('CIN: ${c.cin}'),
                    onTap: () {
                      close(context, null);
                      context.push('/clients/${c.id}');
                    },
                  )),
            ],
            if (vehicles.isNotEmpty) ...[
              _buildSectionHeader('Véhicules'),
              ...vehicles.map((v) => ListTile(
                    leading: const Icon(Icons.directions_car),
                    title: Text('${v.brand} ${v.model}'),
                    subtitle: Text(v.registrationNumber),
                    trailing: StatusBadge(text: v.status),
                    onTap: () {
                      close(context, null);
                      context.push('/vehicles/${v.id}');
                    },
                  )),
            ],
            if (contracts.isNotEmpty) ...[
              _buildSectionHeader('Contrats'),
              ...contracts.map((cn) => ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(cn.contractNumber),
                    subtitle: Text('Status: ${cn.status}'),
                    onTap: () {
                      close(context, null);
                      context.push('/contracts/${cn.id}');
                    },
                  )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}
