import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/contract_insights.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/vehicle_maintenance.dart';
import '../../../data/models/contract_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/lookup_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/global_search_delegate.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/contracts/contract_card.dart';
import '../../widgets/dashboard/revenue_chart.dart';
import '../../widgets/dashboard/stat_card.dart';
import '../../widgets/layout/app_page.dart';
import '../../widgets/motion/motion.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _refresh() async {
    await Future.wait([
      ref.read(dashboardProvider.notifier).refresh(),
      ref.read(contractsProvider.notifier).loadContracts(),
      ref.read(vehiclesProvider.notifier).loadVehicles(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardProvider);
    final companyName = ref.watch(companyNameProvider).value ?? '';
    final contractsAsync = ref.watch(contractsProvider);
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final lookups = ref.watch(lookupsProvider).value ?? const Lookups();

    return AdaptiveLayout(
      child: AppPage.home(
        title: companyName.isNotEmpty ? companyName : 'CarRent Manager',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/license'),
          tooltip: context.tr(AppCopy.back),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            onPressed: () => context.push('/operations'),
            tooltip: context.tr(AppCopy.todaySOperations),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: GlobalSearchDelegate(ref),
            ),
            tooltip: context.tr(AppCopy.globalSearch),
          ),
        ],
        onRefresh: _refresh,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/contracts/new'),
          icon: const Icon(Icons.add),
          label: const AppText(AppCopy.newContract),
        ),
        children: [
          Reveal(
            child: _Header(revenue: statsAsync.value?.totalRevenue),
          ),
          const SizedBox(height: 20),
          contractsAsync.when(
            data: (contracts) => _Priorities(
              contracts: contracts,
              vehicles: vehicles,
              lookups: lookups,
            ),
            loading: () => const AppShimmer.rectangular(height: 140),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          const Reveal(
            child: SectionHeader(title: AppCopy.overview),
          ),
          statsAsync.when(
            data: (stats) => _StatsGrid(stats: stats),
            loading: () => AppShimmer.statsGrid(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          const Reveal(
            child: SectionHeader(title: AppCopy.quickActions),
          ),
          const _QuickActions(),
          const SizedBox(height: 12),
          Reveal(
            child: SectionHeader(
              title: AppCopy.currentRentals,
              actionLabel: AppCopy.seeAll,
              onAction: () => context.go('/contracts'),
            ),
          ),
          contractsAsync.when(
            data: (contracts) => _ActiveRentals(
              contracts: contracts,
              lookups: lookups,
            ),
            loading: () => AppShimmer.listLayer(itemCount: 2),
            error: (_, __) =>
                const AppText(AppCopy.unableToLoadContracts),
          ),
          const SizedBox(height: 12),
          const Reveal(
            child: SectionHeader(
              title: AppCopy.paymentsReceived,
              subtitle: AppCopy.last7Days,
            ),
          ),
          statsAsync.when(
            data: (stats) => Reveal(
              child: RevenueChart(data: stats.weeklyRevenue),
            ),
            loading: () => const AppShimmer.rectangular(height: 200),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.revenue});
  final double? revenue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 5 || hour >= 18 ? AppCopy.goodEvening : AppCopy.goodMorning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          formatLongDay(DateTime.now(), locale: Localizations.localeOf(context))
              .toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        AppText(
          greeting,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 56,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        if (revenue != null) ...[
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined,
                      color: AppColors.gold, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        AppCopy.collectedThisMonth,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: CountUpText(
                          value: revenue!,
                          format: (v) => context.money(v.round()),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// What needs the operator today, in the order it costs money if ignored:
/// vehicles that are late, balances still owed, then documents about to lapse.
class _Priorities extends StatelessWidget {
  const _Priorities({
    required this.contracts,
    required this.vehicles,
    required this.lookups,
  });

  final List<ContractModel> contracts;
  final List<VehicleModel> vehicles;
  final Lookups lookups;

  @override
  Widget build(BuildContext context) {
    final open = contracts.where((c) => c.status != 'completed').toList()
      ..sort((a, b) => a.expectedReturnDate.compareTo(b.expectedReturnDate));
    final late = open.where((c) => c.isLate).toList();
    final unpaid = open.where((c) => c.remainingAmount > 0.009).toList()
      ..sort((a, b) {
        if (a.isLate != b.isLate) return a.isLate ? -1 : 1;
        return a.expectedReturnDate.compareTo(b.expectedReturnDate);
      });

    final maintenance = <(VehicleModel, MaintenanceItem)>[];
    for (final v in vehicles) {
      for (final item in maintenanceAlerts(v)) {
        maintenance.add((v, item));
      }
    }
    maintenance.sort((a, b) => a.$2.urgency.compareTo(b.$2.urgency));

    if (late.isEmpty && unpaid.isEmpty && maintenance.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Icon(AppTone.success.icon, color: AppTone.success.color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: AppText(
                AppCopy.everythingIsInOrderNoLateReturnsOutstanding,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: AppCopy.toHandle, icon: Icons.bolt_outlined),
        if (late.isNotEmpty)
          Reveal(
            index: 0,
            child: _PriorityCard(
              tone: AppTone.danger,
              icon: Icons.schedule,
              title: AppCopy.lateReturns,
              count: late.length,
              onSeeAll: () => context.go('/contracts'),
              rows: [
                for (final c in late.take(3))
                  _PriorityRow(
                    title: lookups.vehicleNameFor(context, c.vehicleId),
                    subtitle: lookups.clientNameFor(context, c.primaryDriverId),
                    chip: returnStatusOf(c).label,
                    tone: AppTone.danger,
                    onTap: () => context.push('/contracts/${c.id}'),
                  ),
              ],
            ),
          ),
        if (unpaid.isNotEmpty) ...[
          const SizedBox(height: 12),
          Reveal(
            index: 1,
            child: _PriorityCard(
              tone: AppTone.warning,
              icon: Icons.payments_outlined,
              title: AppCopy.paymentsToCollect,
              count: unpaid.length,
              onSeeAll: () => context.go('/contracts'),
              rows: [
                for (final c in unpaid.take(3))
                  _PriorityRow(
                    title: lookups.vehicleNameFor(context, c.vehicleId),
                    subtitle: lookups.clientNameFor(context, c.primaryDriverId),
                    chip: context.money(c.remainingAmount),
                    tone: AppTone.warning,
                    onTap: () => context.push('/contracts/${c.id}'),
                  ),
              ],
            ),
          ),
        ],
        if (maintenance.isNotEmpty) ...[
          const SizedBox(height: 12),
          Reveal(
            index: 2,
            child: _PriorityCard(
              tone: maintenance.any((m) => m.$2.tone == AppTone.danger)
                  ? AppTone.danger
                  : AppTone.warning,
              icon: Icons.build_outlined,
              title: AppCopy.maintenanceAndDocuments,
              count: maintenance.length,
              onSeeAll: () => context.go('/vehicles'),
              rows: [
                for (final m in maintenance.take(3))
                  _PriorityRow(
                    title: '${m.$1.brand} ${m.$1.model}',
                    subtitle: '${context.tr(m.$2.label)} · ${m.$1.registrationNumber}',
                    chip: m.$2.status,
                    tone: m.$2.tone,
                    onTap: () => context.push('/vehicles/${m.$1.id}'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PriorityRow {
  const _PriorityRow({
    required this.title,
    required this.subtitle,
    required this.chip,
    required this.tone,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String chip;
  final AppTone tone;
  final VoidCallback onTap;
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.tone,
    required this.icon,
    required this.title,
    required this.count,
    required this.rows,
    required this.onSeeAll,
  });

  final AppTone tone;
  final IconData icon;
  final String title;
  final int count;
  final List<_PriorityRow> rows;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      accent: tone.color,
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(
              children: [
                Icon(icon, color: tone.color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                    child: AppText(title, style: theme.textTheme.titleSmall)),
                StatusChip(label: '$count', tone: tone, dense: true),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (final row in rows)
            InkWell(
              onTap: row.onTap,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppText(row.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          AppText(row.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: StatusChip(
                            label: row.chip, tone: row.tone, dense: true),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          if (count > rows.length)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onSeeAll,
                child: AppText(context.messages.seeCount((count).toString())),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    // The row height is explicit so a large system font grows the cell instead
    // of clipping the two-line label.
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 700;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isWide ? 4 : 2,
        mainAxisExtent: 124 * textScale.clamp(1.0, 1.6),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          Reveal(
            index: 0,
            child: StatCard(
              title: AppCopy.available61af94,
              countTo: stats.availableVehicles,
              value: stats.availableVehicles.toString(),
              icon: Icons.directions_car,
              color: AppTone.success.color,
              onTap: () => context.go('/vehicles'),
            ),
          ),
          Reveal(
            index: 1,
            child: StatCard(
              title: AppCopy.rentede06686,
              countTo: stats.rentedVehicles,
              value: stats.rentedVehicles.toString(),
              icon: Icons.key_outlined,
              color: AppTone.warning.color,
              onTap: () => context.go('/vehicles'),
            ),
          ),
          Reveal(
            index: 2,
            child: StatCard(
              title: AppCopy.activeContracts,
              countTo: stats.activeContracts,
              value: stats.activeContracts.toString(),
              icon: Icons.receipt_long,
              color: AppTone.info.color,
              onTap: () => context.go('/contracts'),
            ),
          ),
          Reveal(
            index: 3,
            child: StatCard(
              title: AppCopy.overdue,
              countTo: stats.lateContracts,
              value: stats.lateContracts.toString(),
              icon: Icons.schedule,
              color: stats.lateContracts > 0
                  ? AppTone.danger.color
                  : AppColors.textSecondary,
              onTap: () => context.go('/contracts'),
            ),
          ),
        ],
      );
    });
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.person_add_outlined, AppCopy.client, '/clients/add'),
      (Icons.directions_car_outlined, AppCopy.vehicle, '/vehicles/add'),
      (Icons.badge_outlined, AppCopy.drivers, '/chauffeurs'),
      (Icons.auto_awesome_outlined, AppCopy.assistant, '/assistant'),
    ];
    return Reveal(
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: AppCard(
                onTap: () => context.push(actions[i].$3),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(actions[i].$1, color: AppColors.pennyDark, size: 26),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: AppText(
                        actions[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveRentals extends StatelessWidget {
  const _ActiveRentals({required this.contracts, required this.lookups});
  final List<ContractModel> contracts;
  final Lookups lookups;

  @override
  Widget build(BuildContext context) {
    final open = contracts.where((c) => c.status != 'completed').toList()
      ..sort((a, b) {
        if (a.isLate != b.isLate) return a.isLate ? -1 : 1;
        return a.expectedReturnDate.compareTo(b.expectedReturnDate);
      });

    if (open.isEmpty) {
      return AppCard(
        child: AppText(
          AppCopy.noRentalInProgressCreateAContractTo,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: [
        for (final (i, c) in open.take(5).indexed)
          Reveal(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ContractCard(
                contract: c,
                lookups: lookups,
                compact: true,
                onTap: () => context.push('/contracts/${c.id}'),
              ),
            ),
          ),
      ],
    );
  }
}
