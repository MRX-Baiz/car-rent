import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/today_operations.dart';
import '../../../data/models/vehicle_model.dart';
import '../../providers/contract_provider.dart';
import '../../providers/lookup_provider.dart';
import '../../providers/today_operations_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_chip.dart';

class TodayOperationsScreen extends ConsumerWidget {
  const TodayOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = ref.watch(todayOperationsProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final lookups = ref.watch(lookupsProvider);

    return AdaptiveLayout(
      child: Scaffold(
        appBar: AppBar(
          title: const AppText(AppCopy.todaySOperations),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/dashboard'),
            tooltip: context.tr(AppCopy.back),
          ),
        ),
        body: operations.when(
          loading: () => Padding(
            padding: EdgeInsets.all(16),
            child: AppShimmer.listLayer(itemCount: 5),
          ),
          error: (_, __) => const Center(
            child: AppText(AppCopy.unableToLoadTodaySOperations),
          ),
          data: (queue) {
            final vehicleList = vehicles.value ?? const <VehicleModel>[];
            final names = lookups.value ?? const Lookups();
            final vehiclesById = {
              for (final vehicle in vehicleList)
                if (vehicle.id != null) vehicle.id!: vehicle,
            };
            return RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.read(contractsProvider.notifier).loadContracts(),
                  ref.read(vehiclesProvider.notifier).loadVehicles(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _Summary(queue: queue),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: AppCopy.todaySPriorities,
                    subtitle: AppCopy.handleReturnsAndBlockedVehiclesFirst,
                  ),
                  _OperationCard(
                    title: AppCopy.pickupsToday,
                    empty: AppCopy.noPickupsScheduledToday,
                    icon: Icons.key_outlined,
                    tone: AppTone.info,
                    rows: [
                      for (final contract in queue.pickups)
                        _OperationRow(
                          title:
                              names.vehicleNameFor(context, contract.vehicleId),
                          subtitle:
                              names.clientNameFor(context, contract.clientId),
                          trailing: context.money(contract.remainingAmount),
                          onTap: () =>
                              context.push('/contracts/${contract.id}'),
                        ),
                    ],
                  ),
                  _OperationCard(
                    title: AppCopy.returnsToday,
                    empty: AppCopy.noReturnsScheduledToday,
                    icon: Icons.assignment_return_outlined,
                    tone: AppTone.warning,
                    rows: [
                      for (final contract in queue.returns)
                        _OperationRow(
                          title:
                              names.vehicleNameFor(context, contract.vehicleId),
                          subtitle:
                              names.clientNameFor(context, contract.clientId),
                          trailing: contract.remainingAmount > 0.009
                              ? context.money(contract.remainingAmount)
                              : AppCopy.paid,
                          onTap: () =>
                              context.push('/contracts/${contract.id}'),
                        ),
                    ],
                  ),
                  _OperationCard(
                    title: AppCopy.lateReturns,
                    empty: AppCopy.noLateReturns,
                    icon: Icons.schedule_outlined,
                    tone: AppTone.danger,
                    rows: [
                      for (final contract in queue.lateReturns)
                        _OperationRow(
                          title:
                              names.vehicleNameFor(context, contract.vehicleId),
                          subtitle:
                              names.clientNameFor(context, contract.clientId),
                          trailing:
                              '${context.tr(AppCopy.since)} ${formatDate(contract.expectedReturnDate)}',
                          onTap: () =>
                              context.push('/contracts/${contract.id}'),
                        ),
                    ],
                  ),
                  _OperationCard(
                    title: AppCopy.amountsToCollect,
                    empty: AppCopy.noOutstandingAmounts,
                    icon: Icons.payments_outlined,
                    tone: AppTone.warning,
                    rows: [
                      for (final contract in queue.unpaid)
                        _OperationRow(
                          title:
                              names.vehicleNameFor(context, contract.vehicleId),
                          subtitle:
                              names.clientNameFor(context, contract.clientId),
                          trailing: context.money(contract.remainingAmount),
                          onTap: () =>
                              context.push('/contracts/${contract.id}'),
                        ),
                    ],
                  ),
                  _OperationCard(
                    title: AppCopy.carsBlockedForMaintenance,
                    empty: AppCopy.noCarsAreBlockedForMaintenance,
                    icon: Icons.build_outlined,
                    tone: AppTone.danger,
                    rows: [
                      for (final vehicleId in queue.blockedVehicleIds)
                        if (vehiclesById[vehicleId] case final vehicle?)
                          _OperationRow(
                            title: '${vehicle.brand} ${vehicle.model}',
                            subtitle: vehicle.registrationNumber,
                            trailing: AppCopy.blocked,
                            onTap: () => context.push('/vehicles/$vehicleId'),
                          ),
                    ],
                  ),
                  _OperationCard(
                    title: AppCopy.expiringDocuments,
                    empty: AppCopy.noDocumentsNeedRenewal,
                    icon: Icons.folder_shared_outlined,
                    tone: AppTone.warning,
                    rows: [
                      for (final document in queue.expiringDocuments)
                        if (vehiclesById[document.vehicleId]
                            case final vehicle?)
                          _OperationRow(
                            title: '${vehicle.brand} ${vehicle.model}',
                            subtitle:
                                '${context.tr(_documentLabel(document.type))} · ${vehicle.registrationNumber}',
                            trailing: _documentStatus(
                              context,
                              document.daysUntilDue,
                            ),
                            onTap: () =>
                                context.push('/vehicles/${document.vehicleId}'),
                          ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _documentLabel(VehicleDocumentType type) => switch (type) {
      VehicleDocumentType.insurance => AppCopy.insurance,
      VehicleDocumentType.technicalInspection => AppCopy.technicalInspection,
      VehicleDocumentType.roadTax => AppCopy.roadTax,
    };

String _documentStatus(BuildContext context, int daysUntilDue) {
  if (daysUntilDue < 0) {
    return context.messages.expiredDays((-daysUntilDue).toString());
  }
  if (daysUntilDue == 0) return AppCopy.expiresToday;
  return context.messages.expiresInDays(daysUntilDue.toString());
}

class _Summary extends StatelessWidget {
  const _Summary({required this.queue});
  final TodayOperationsQueue queue;

  @override
  Widget build(BuildContext context) {
    final tone =
        queue.lateReturns.isNotEmpty || queue.blockedVehicleIds.isNotEmpty
            ? AppTone.danger
            : queue.total == 0
                ? AppTone.success
                : AppTone.warning;
    return AppCard(
      accent: tone.color,
      child: Row(
        children: [
          Icon(tone.icon, color: tone.color, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: AppText(
              queue.total == 0
                  ? AppCopy.everythingIsInOrderToday
                  : '${queue.total} ${context.tr(AppCopy.operationsToFollowUpToday)}',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({
    required this.title,
    required this.empty,
    required this.icon,
    required this.tone,
    required this.rows,
  });

  final String title;
  final String empty;
  final IconData icon;
  final AppTone tone;
  final List<_OperationRow> rows;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          accent: tone.color,
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: tone.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppText(title,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  StatusChip(label: '${rows.length}', tone: tone, dense: true),
                ],
              ),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 12, start: 34),
                  child: AppText(empty,
                      style: const TextStyle(color: AppColors.textSecondary)),
                )
              else ...[
                const SizedBox(height: 6),
                for (final row in rows) row,
              ],
            ],
          ),
        ),
      );
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: AppText(trailing,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ),
        onTap: onTap,
      );
}
