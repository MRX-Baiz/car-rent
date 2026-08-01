import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/models/contract_model.dart';
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
            tooltip: 'Retour',
          ),
          title: const Text('Contrats'),
          bottom: TabBar(
            controller: _tabController,
            // Scrolls sideways rather than cramming four labels into a phone
            // width; centred so it still looks deliberate on desktop.
            isScrollable: true,
            tabAlignment: TabAlignment.center,
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
          onPressed: () => context.push('/contracts/new'),
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
                      context.push('/contracts/${contract.id}');
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(text: contract.status),
                      if (contract.status == 'completed') ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Supprimer le contrat ?'),
                                content: Text('Voulez-vous vraiment supprimer le contrat n° ${contract.contractNumber} ? Cette action supprimera également les paiements associés et est irréversible.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Annuler'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true && context.mounted) {
                              try {
                                await ref.read(contractsProvider.notifier).deleteContract(contract.id!);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Contrat supprimé avec succès.')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erreur lors de la suppression: $e')),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ],
                  ),
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

