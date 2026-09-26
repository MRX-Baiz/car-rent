import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/search_result.dart';
import '../../providers/agency_search_provider.dart';
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
      return const Center(child: AppText(AppCopy.typeAtLeast2Characters));
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return FutureBuilder(
      future: ref.read(agencySearchResultsProvider(query).future),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: AppText(context.trError(snapshot.error)));
        }

        final results = snapshot.data ?? const AgencySearchResults();
        final clients = results.clients;
        final vehicles = results.vehicles;
        final contracts = results.contracts;

        if (clients.isEmpty && vehicles.isEmpty && contracts.isEmpty) {
          return const Center(child: AppText(AppCopy.noResultsFound));
        }

        return ListView(
          children: [
            if (clients.isNotEmpty) ...[
              _buildSectionHeader(context, AppCopy.clients),
              ...clients.map((c) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(c.title),
                    subtitle:
                        Text(context.messages.nationalIdValue(c.subtitle)),
                    onTap: () {
                      close(context, null);
                      context.push('/clients/${c.id}');
                    },
                  )),
            ],
            if (vehicles.isNotEmpty) ...[
              _buildSectionHeader(context, AppCopy.vehicles),
              ...vehicles.map((v) => ListTile(
                    leading: const Icon(Icons.directions_car),
                    title: Text(v.title),
                    subtitle: Text(v.subtitle),
                    trailing: StatusBadge(text: v.status ?? ''),
                    onTap: () {
                      close(context, null);
                      context.push('/vehicles/${v.id}');
                    },
                  )),
            ],
            if (contracts.isNotEmpty) ...[
              _buildSectionHeader(context, AppCopy.contracts),
              ...contracts.map((cn) => ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(cn.title),
                    subtitle:
                        AppText(context.messages.searchStatus(context.tr(({
                                  'active': AppCopy.active,
                                  'completed': AppCopy.completed,
                                  'late': AppCopy.overdue,
                                }[cn.subtitle] ??
                                cn.subtitle)
                            .toString()))),
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AppText(
        context.tr(title).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}
