import 'package:flutter/material.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
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
import '../../widgets/contracts/contract_delete_dialog.dart';
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
        lookups.vehicleNameFor(context, c.vehicleId).toLowerCase().contains(_query) ||
        (lookups.vehicle(c.vehicleId)?.registrationNumber ?? '')
            .toLowerCase()
            .contains(_query) ||
        lookups.clientNameFor(context, c.primaryDriverId).toLowerCase().contains(_query);
  }

  Future<void> _delete(ContractModel contract) async {
    try {
      await ref.read(contractsProvider.notifier).deleteContract(contract.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText(AppCopy.contractDeletedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(context.trError(e))),
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
            tooltip: context.tr(AppCopy.back),
          ),
          title: const AppText(AppCopy.contracts),
          actions: [
            IconButton(
              tooltip: context.tr(AppCopy.availabilityCalendarb8c1ea),
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () => context.push('/availability'),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            // Scrolls sideways rather than cramming four labels into a
            // phone width; centred so it still looks deliberate on
            // desktop.
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              const Tab(child: AppText(AppCopy.all)),
              const Tab(child: AppText(AppCopy.active)),
              const Tab(child: AppText(AppCopy.completed)),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppText(AppCopy.overdue),
                    if (lateCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTone.danger.color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: AppText('$lateCount',
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
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.tr(AppCopy.contractNoVehicleOrClient),
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
          label: const AppText(AppCopy.newContract),
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
                ? AppCopy.noContractsFound
                : switch (filter) {
                    'late' => AppCopy.noOverdueReturns,
                    'completed' => AppCopy.noCompletedContracts,
                    'active' => AppCopy.noActiveRentals,
                    _ => AppCopy.noContracts,
                  },
            subtitle: searching
                ? AppCopy.tryAnotherNameVehicleOrNumber
                : filter == 'late'
                    ? AppCopy.allVehiclesWereReturnedOnTime
                    : AppCopy.createANewContractToGetStarted,
            icon:
                filter == 'late' ? Icons.task_alt : Icons.receipt_long_outlined,
            actionLabel:
                filter == 'late' || searching ? null : AppCopy.newContract,
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
                child: Dismissible(
                  key: ValueKey(contract.id ?? index),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: AppTone.danger.color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child:
                        const Icon(Icons.delete_forever, color: Colors.white),
                  ),
                  confirmDismiss: (_) =>
                      confirmDeleteContract(context, contract),
                  onDismissed: (_) => _delete(contract),
                  child: ContractCard(
                    contract: contract,
                    lookups: lookups,
                    onTap: () {
                      if (contract.id != null) {
                        context.push('/contracts/${contract.id}');
                      }
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => AppShimmer.listLayer(),
      error: (error, _) => Center(
        child: AppText(
          context.trError(error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
