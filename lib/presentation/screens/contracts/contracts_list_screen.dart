import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/contract_model.dart';
import '../../providers/contract_provider.dart';
import '../../providers/lookup_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/contracts/contract_card.dart';
import '../../widgets/motion/backdrop_page.dart';

class ContractsListScreen extends ConsumerStatefulWidget {
  const ContractsListScreen({super.key});

  @override
  ConsumerState<ContractsListScreen> createState() =>
      _ContractsListScreenState();
}

class _ContractsListScreenState extends ConsumerState<ContractsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _query = '';

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

  // 'late' is derived from the return date, never stored, so the tabs filter
  // on isLate rather than on status or the late tab would always be empty.
  bool _matches(ContractModel c, String filter, Lookups lookups) {
    final matchesFilter = switch (filter) {
      'active' => c.status == 'active',
      'completed' => c.status == 'completed',
      'late' => c.isLate,
      _ => true,
    };
    if (!matchesFilter) return false;
    if (_query.isEmpty) return true;
    return c.contractNumber.toLowerCase().contains(_query) ||
        lookups.vehicleName(c.vehicleId).toLowerCase().contains(_query) ||
        (lookups.vehicle(c.vehicleId)?.registrationNumber ?? '')
            .toLowerCase()
            .contains(_query) ||
        lookups.clientName(c.primaryDriverId).toLowerCase().contains(_query);
  }

  Future<void> _confirmDelete(ContractModel contract) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le contrat ?'),
        content: Text(
            'Voulez-vous vraiment supprimer le contrat n° ${contract.contractNumber} ? Cette action supprimera également les paiements associés et est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTone.danger.color),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await ref.read(contractsProvider.notifier).deleteContract(contract.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contrat supprimé avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contractsAsync = ref.watch(contractsProvider);
    final lookups = ref.watch(lookupsProvider).value ?? const Lookups();
    final contracts = contractsAsync.value ?? const <ContractModel>[];
    final lateCount = contracts.where((c) => c.isLate).length;

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
            // Scrolls sideways rather than cramming four labels into a
            // phone width; centred so it still looks deliberate on
            // desktop.
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              const Tab(text: 'Tous'),
              const Tab(text: 'En cours'),
              const Tab(text: 'Terminés'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('En retard'),
                    if (lateCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTone.danger.color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$lateCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: BackdropPage(
            child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'N° contrat, véhicule ou client',
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final filter in const [
                    'all',
                    'active',
                    'completed',
                    'late'
                  ])
                    _buildTabContent(contractsAsync, filter, lookups),
                ],
              ),
            ),
          ],
        )),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/contracts/new'),
          icon: const Icon(Icons.add),
          label: const Text('Nouveau contrat'),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    AsyncValue<List<ContractModel>> contractsAsync,
    String filter,
    Lookups lookups,
  ) {
    return contractsAsync.when(
      data: (contracts) {
        final filtered =
            contracts.where((c) => _matches(c, filter, lookups)).toList()
              ..sort((a, b) {
                // Late first, then soonest return: what to chase reads first.
                if (filter != 'completed' && a.isLate != b.isLate) {
                  return a.isLate ? -1 : 1;
                }
                if (filter == 'completed' || filter == 'all') {
                  return b.startDate.compareTo(a.startDate);
                }
                return a.expectedReturnDate.compareTo(b.expectedReturnDate);
              });

        if (filtered.isEmpty) {
          final searching = _query.isNotEmpty;
          return EmptyStateWidget(
            title: searching
                ? 'Aucun contrat trouvé.'
                : switch (filter) {
                    'late' => 'Aucun retard.',
                    'completed' => 'Aucun contrat terminé.',
                    'active' => 'Aucune location en cours.',
                    _ => 'Aucun contrat.',
                  },
            subtitle: searching
                ? 'Essayez un autre nom, véhicule ou numéro.'
                : filter == 'late'
                    ? 'Tous les véhicules sont rentrés à l’heure.'
                    : 'Créez un nouveau contrat pour commencer.',
            icon:
                filter == 'late' ? Icons.task_alt : Icons.receipt_long_outlined,
            actionLabel:
                filter == 'late' || searching ? null : 'Nouveau contrat',
            onAction: () => context.push('/contracts/new'),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(contractsProvider.notifier).loadContracts(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final contract = filtered[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ContractCard(
                  contract: contract,
                  lookups: lookups,
                  onTap: () {
                    if (contract.id != null) {
                      context.push('/contracts/${contract.id}');
                    }
                  },
                  onDelete: contract.status == 'completed'
                      ? () => _confirmDelete(contract)
                      : null,
                ),
              );
            },
          ),
        );
      },
      loading: () => AppShimmer.listLayer(),
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
