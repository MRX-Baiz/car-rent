import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/models/contract_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/contract_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/status_badge.dart';

class ContractsListScreen extends ConsumerStatefulWidget {
  const ContractsListScreen({super.key});

  @override
  ConsumerState<ContractsListScreen> createState() =>
      _ContractsListScreenState();
}

class _ContractsListScreenState extends ConsumerState<ContractsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(
      () => ref.read(contractsProvider.notifier).loadContracts(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contractsAsync = ref.watch(contractsProvider);
    final theme = Theme.of(context);

    return AdaptiveLayout(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contrats'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Tous'),
              Tab(text: 'Actifs'),
              Tab(text: 'Complétés'),
              Tab(text: 'En retard'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTabContent(context, theme, contractsAsync, 'all'),
            _buildTabContent(context, theme, contractsAsync, 'active'),
            _buildTabContent(context, theme, contractsAsync, 'completed'),
            _buildTabContent(context, theme, contractsAsync, 'late'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/contracts/new'),
          icon: const Icon(Icons.add),
          label: const Text('Nouveau contrat'),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    ThemeData theme,
    AsyncValue<List<ContractModel>> contractsAsync,
    String filter,
  ) {
    return contractsAsync.when(
      data: (contracts) {
        final filtered = contracts.where((c) {
          if (filter == 'all') return true;
          return c.status == filter;
        }).toList();

        if (filtered.isEmpty) {
          return const EmptyStateWidget(
            title: 'Aucun contrat trouvé.',
            subtitle: 'Créez un nouveau contrat pour commencer.',
            icon: Icons.receipt_long_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(contractsProvider.notifier).loadContracts(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final contract = filtered[index];
              final start = _dateFormatter.format(contract.startDate);
              final end = _dateFormatter.format(contract.expectedReturnDate);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  onTap: () {
                    if (contract.id != null) {
                      context.go('/contracts/${contract.id}');
                    }
                  },
                  leading: CircleAvatar(
                    child: Text(
                      contract.contractNumber.length >= 4
                          ? contract.contractNumber
                              .substring(contract.contractNumber.length - 4)
                          : contract.contractNumber,
                    ),
                  ),
                  title: Text(
                    contract.contractNumber,
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contrat pour véhicule #${contract.vehicleId} - client #${contract.primaryDriverId}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$start → $end',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Reste: ${contract.remainingAmount.toStringAsFixed(2)} MAD',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: StatusBadge(text: contract.status),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Erreur lors du chargement des contrats.\n'
          'خطأ أثناء تحميل العقود.\n'
          'Contracts loading error: $error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

