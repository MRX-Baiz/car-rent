import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/license/license_features.dart';
import '../../../core/license/license_manager.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/vehicle_expense_labels.dart';
import '../../../core/utils/vehicle_labels.dart';
import '../../../core/utils/vehicle_maintenance.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../domain/entities/vehicle_expense.dart';
import '../../../domain/entities/vehicle_profitability.dart';
import '../../providers/lookup_provider.dart';
import '../../providers/vehicle_profitability_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/alert_banner.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/collapsible_section.dart';
import '../../widgets/common/detail_row.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/form_section.dart';
import '../../widgets/common/plate_badge.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/common/vehicle_photo.dart';
import '../../widgets/contracts/contract_card.dart';
import '../../widgets/motion/backdrop_page.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({
    super.key,
    required this.vehicleId,
  });

  final int vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppText(AppCopy.vehicle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: context.tr(AppCopy.editVehicle),
            onPressed: () {
              final vehicle = _findVehicle(vehiclesAsync.value, vehicleId);
              if (vehicle != null) {
                context.push('/vehicles/$vehicleId/edit', extra: vehicle);
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: () {
        final vehicle = _findVehicle(vehiclesAsync.value, vehicleId);
        if (vehicle == null || vehicle.status != 'available') return null;
        return BottomActionBar(
          child: FilledButton.icon(
            onPressed: () => context.push('/contracts/new', extra: vehicleId),
            icon: const Icon(Icons.key_outlined),
            label: const AppText(AppCopy.rentThisVehicle),
          ),
        );
      }(),
      body: BackdropPage(
          child: vehiclesAsync.when(
        data: (vehicles) {
          final vehicle = _findVehicle(vehicles, vehicleId);
          if (vehicle == null) {
            return const EmptyStateWidget(
              title: AppCopy.vehicleNotFound,
              subtitle: AppCopy.thisVehicleMayHaveBeenDeleted,
              icon: Icons.directions_car_filled_outlined,
            );
          }
          return _Body(
              vehicle: vehicle, onDelete: () => _delete(context, ref, vehicle));
        },
        loading: () => AppShimmer.detailLayer(),
        error: (error, _) => Center(
          child: AppText(
            context.trError(error),
            textAlign: TextAlign.center,
          ),
        ),
      )),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, VehicleModel vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText(AppCopy.deleteVehicle),
        content: const AppText(AppStrings.confirmDeleteVehicle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const AppText(AppCopy.cancel),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTone.danger.color),
            onPressed: () => Navigator.of(context).pop(true),
            child: const AppText(AppCopy.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (vehicle.id != null) {
        await ref.read(vehiclesProvider.notifier).deleteVehicle(vehicle.id!);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText(AppStrings.successDeleted)),
        );
        context.go('/vehicles');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            context.trError(e),
          ),
        ),
      );
    }
  }

  VehicleModel? _findVehicle(List<VehicleModel>? list, int id) {
    if (list == null) return null;
    for (final v in list) {
      if (v.id == id) return v;
    }
    return null;
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.vehicle, required this.onDelete});
  final VehicleModel vehicle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = maintenanceItems(vehicle);
    final alerts = maintenanceAlerts(vehicle);
    final vehicleId = vehicle.id;
    final history = vehicleId == null
        ? null
        : ref.watch(vehicleContractsProvider(vehicleId));
    final lookups = ref.watch(lookupsProvider).value ?? const Lookups();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: 'vehicle_${vehicle.id}',
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VehiclePhoto(
                      vehicle: vehicle, borderRadius: 16, iconSize: 72),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${vehicle.brand} ${vehicle.model}',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            PlateBadge(vehicle.registrationNumber),
                            AppText(
                                context.messages
                                    .vehicleYear((vehicle.year).toString()),
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(text: vehicle.status),
                ],
              ),
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 16),
                AlertBanner(
                  tone: alerts.any((a) => a.tone == AppTone.danger)
                      ? AppTone.danger
                      : AppTone.warning,
                  title: alerts.length == 1
                      ? AppCopy.message1ItemNeedsAttention
                      : context.messages
                          .attentionCount((alerts.length).toString()),
                  message: alerts
                      .map((a) =>
                          '${context.tr(a.label)} : ${context.tr(a.status)}')
                      .join('\n'),
                ),
              ],
              const SectionHeader(
                title: AppCopy.vehicleInformation,
                padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MetricGrid(items: [
                      MetricItem(Icons.speed_outlined, AppCopy.mileage,
                          context.distance(vehicle.currentMileage)),
                      MetricItem(fuelTypeIcon(vehicle.fuelType), AppCopy.fuel,
                          fuelTypeName(vehicle.fuelType)),
                      MetricItem(Icons.local_gas_station_outlined,
                          AppCopy.fuelLevel, '${vehicle.fuelLevel} %'),
                      MetricItem(
                          Icons.settings_outlined,
                          AppCopy.transmissioncbe91c,
                          transmissionName(vehicle.transmission)),
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        AppText(AppCopy.generalCondition,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary)),
                        const Spacer(),
                        StatusChip(
                          label: conditionName(vehicle.conditionStatus),
                          tone: conditionTone(vehicle.conditionStatus),
                          icon: conditionIcon(vehicle.conditionStatus),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader(
                title: AppCopy.photosAndDamage,
                padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
              ),
              AppCard(
                onTap: () => context.push('/vehicles/${vehicle.id}/photos'),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.photo_camera_back_outlined,
                          color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(AppCopy.exteriorPhotosAndDamage,
                              style: theme.textTheme.titleSmall),
                          AppText(
                            AppCopy.frontRearSidesAndExistingDamage,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 0),
                // Collapsed by default — the alert banner above already
                // surfaces anything urgent; this is the full breakdown for
                // when the operator actually wants it, not a wall of dates
                // shown whether needed or not.
                child: CollapsibleSection(
                  icon: Icons.build_outlined,
                  title: AppCopy.maintenanceAndLegalDocuments,
                  subtitle: alerts.isEmpty
                      ? AppCopy.upToDate
                      : context.messages
                          .monitorCount((alerts.length).toString()),
                  badge: StatusChip(
                    label:
                        alerts.isEmpty ? AppCopy.upToDate : '${alerts.length}',
                    tone: alerts.isEmpty
                        ? AppTone.success
                        : (alerts.any((a) => a.tone == AppTone.danger)
                            ? AppTone.danger
                            : AppTone.warning),
                    icon: alerts.isEmpty ? Icons.check : null,
                    dense: true,
                  ),
                  children: [
                    for (final item in items)
                      DetailRow(
                        icon: item.icon,
                        label: item.label,
                        value: context.tr(item.value),
                        trailing: StatusChip(
                          label: item.status,
                          tone: item.tone,
                          icon: item.needsAttention ? item.tone.icon : null,
                          dense: true,
                        ),
                      ),
                  ],
                ),
              ),
              if (vehicleId != null)
                ValueListenableBuilder<Set<String>>(
                  valueListenable: licenseFeaturesSignal,
                  builder: (context, features, _) {
                    if (!features.contains(LicenseFeature.profitability)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 20, 4, 0),
                      child: _ProfitabilitySection(vehicleId: vehicleId),
                    );
                  },
                ),
              SectionHeader(
                title: AppCopy.rentalHistory,
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                actionLabel: AppCopy.allContracts,
                onAction: () => context.go('/contracts'),
              ),
              if (history == null)
                const SizedBox.shrink()
              else
                history.when(
                  data: (contracts) => contracts.isEmpty
                      ? AppCard(
                          child: AppText(
                            AppCopy.thisVehicleHasNotBeenRentedYet,
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      : Column(
                          children: [
                            for (final c in contracts.take(3))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ContractCard(
                                  contract: c,
                                  lookups: lookups,
                                  compact: true,
                                  onTap: () =>
                                      context.push('/contracts/${c.id}'),
                                ),
                              ),
                          ],
                        ),
                  loading: () => const AppShimmer.rectangular(height: 80),
                  error: (_, __) =>
                      const AppText(AppCopy.historyIsUnavailableAtTheMoment),
                ),
              const SizedBox(height: 16),
              AppText(
                context.messages.recordDates(
                    (formatDate(vehicle.createdAt)).toString(),
                    (formatDate(vehicle.updatedAt)).toString()),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTone.danger.color,
                  side: BorderSide(color: AppTone.danger.color),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const AppText(AppCopy.deleteThisVehicle01bd94),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Revenue, rental days, utilization and expenses for this vehicle — the
/// numbers that say whether it's worth buying again or selling. Collapsed by
/// default, same as the maintenance section above it; the net profit stays
/// visible in the badge either way.
class _ProfitabilitySection extends ConsumerWidget {
  const _ProfitabilitySection({required this.vehicleId});
  final int vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profitability = ref.watch(vehicleProfitabilityProvider(vehicleId));
    final expenses = ref.watch(vehicleExpensesProvider(vehicleId));

    return profitability.when(
      data: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCollapsible(context, value),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showAddExpenseSheet(context, ref, vehicleId),
            icon: const Icon(Icons.add),
            label: const AppText(AppCopy.addAnExpense),
          ),
          expenses.when(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final expense in items)
                            _ExpenseRow(
                              expense: expense,
                              onDelete: () async {
                                await ref.read(deleteVehicleExpenseProvider)(
                                    expense.id!);
                                ref.invalidate(
                                    vehicleExpensesProvider(vehicleId));
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      loading: () => const AppShimmer.rectangular(height: 64),
      error: (error, _) => AppText(context.trError(error)),
    );
  }

  Widget _buildCollapsible(BuildContext context, VehicleProfitability value) {
    final netTone = value.netProfit >= 0 ? AppTone.success : AppTone.danger;
    final utilization = value.utilizationPercent;
    return CollapsibleSection(
      icon: Icons.trending_up,
      title: AppCopy.profitability,
      badge: StatusChip(
        label: context.money(value.netProfit),
        tone: netTone,
        icon: value.netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
        dense: true,
      ),
      children: [
        DetailRow(
          icon: Icons.payments_outlined,
          label: AppCopy.revenue,
          value: context.money(value.revenue),
        ),
        DetailRow(
          icon: Icons.event_available_outlined,
          label: AppCopy.rentalDaysLabel,
          value: context.messages.rentalDays(value.rentalDays.toString()),
        ),
        DetailRow(
          icon: Icons.donut_large_outlined,
          label: AppCopy.utilizationRate,
          value: utilization == null
              ? context.tr(AppCopy.notTrackedYet)
              : '${utilization.round()} %',
        ),
        for (final entry in value.expensesByCategory.entries)
          if (entry.value > 0)
            DetailRow(
              icon: expenseCategoryIcon(entry.key),
              label: expenseCategoryLabel(entry.key),
              value: context.money(entry.value),
            ),
        DetailRow(
          icon: Icons.summarize_outlined,
          label: AppCopy.totalExpenses,
          value: context.money(value.totalExpenses),
        ),
        DetailRow(
          icon: Icons.account_balance_wallet_outlined,
          label: AppCopy.netProfit,
          value: context.money(value.netProfit),
        ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.onDelete});
  final VehicleExpense expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppTone.danger.soft,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText(AppCopy.deleteThisExpenseQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText(AppCopy.cancel),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppTone.danger.color),
              onPressed: () => Navigator.pop(context, true),
              child: const AppText(AppCopy.delete),
            ),
          ],
        ),
      ).then((confirmed) => confirmed ?? false),
      onDismissed: (_) => onDelete(),
      child: DetailRow(
        icon: expenseCategoryIcon(expense.category),
        label: expenseCategoryLabel(expense.category),
        value: '${context.money(expense.amount)} · ${formatDate(expense.date)}',
      ),
    );
  }
}

Future<void> _showAddExpenseSheet(
    BuildContext outerContext, WidgetRef ref, int vehicleId) async {
  var category = VehicleExpenseCategory.repair;
  var date = DateTime.now();
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  await showModalBottomSheet<void>(
    context: outerContext,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(AppCopy.addAnExpense,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  AppText(AppCopy.expenseCategoryLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in VehicleExpenseCategory.values)
                        ChoiceChip(
                          avatar: Icon(expenseCategoryIcon(option), size: 18),
                          label:
                              AppText(context.tr(expenseCategoryLabel(option))),
                          selected: category == option,
                          onSelected: (_) =>
                              setSheetState(() => category = option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr(AppCopy.expenseAmount),
                      suffixText: 'MAD',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2015),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setSheetState(() => date = picked);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 18),
                        const SizedBox(width: 8),
                        AppText(
                            '${context.tr(AppCopy.expenseDateLabel)} : ${formatDate(date)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                        labelText: context.tr(AppCopy.expenseNoteOptional)),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: AppCopy.save,
                    icon: Icons.save_outlined,
                    onPressed: () async {
                      final amount = double.tryParse(
                              amountController.text.replaceAll(',', '.')) ??
                          0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: AppText(AppCopy.enterAValidAmount)),
                        );
                        return;
                      }
                      try {
                        await ref.read(recordVehicleExpenseProvider)(
                          VehicleExpense(
                            id: null,
                            vehicleId: vehicleId,
                            category: category,
                            amount: amount,
                            date: date,
                            notes: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                          ),
                        );
                        ref.invalidate(vehicleExpensesProvider(vehicleId));
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (outerContext.mounted) {
                          ScaffoldMessenger.of(outerContext).showSnackBar(
                            const SnackBar(
                                content: AppText(AppCopy.expenseSaved)),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: AppText(context.trError(error))),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  amountController.dispose();
  noteController.dispose();
}
