import 'package:flutter/material.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/contract_insights.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/contract_model.dart';
import '../../providers/contract_payment_provider.dart';
import '../../providers/contract_progress_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/lookup_provider.dart';
import '../../widgets/common/alert_banner.dart';
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
import '../../widgets/contracts/contract_delete_dialog.dart';
import 'contract_signature_card.dart';
import '../../widgets/motion/backdrop_page.dart';

class ContractDetailScreen extends ConsumerStatefulWidget {
  const ContractDetailScreen({
    super.key,
    required this.contractId,
  });

  final int contractId;

  @override
  ConsumerState<ContractDetailScreen> createState() =>
      _ContractDetailScreenState();
}

class _ContractDetailScreenState extends ConsumerState<ContractDetailScreen> {
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
  Future<void> _refreshPayments() async {
    ref.invalidate(contractPaymentHistoryProvider(widget.contractId));
    await ref
        .read(contractsProvider.notifier)
        .refreshPaymentsForContract(widget.contractId);
    await ref.read(dashboardProvider.notifier).refresh();
  }

  Future<void> _addPayment(ContractModel contract) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final remaining = contract.remainingAmount;

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText(AppCopy.addAPayment),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                context.messages
                    .balanceDueAmount((context.money(remaining)).toString()),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.tr(AppCopy.amountDue),
                  suffixText: 'MAD',
                  helperText: context.tr(AppCopy.enterTheAmountPaidByTheClient),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr(AppCopy.theAmountIsRequired);
                  }
                  final v = double.tryParse(value);
                  if (v == null || v <= 0) {
                    return context.tr(AppCopy.invalidAmount);
                  }
                  if (v > remaining + 0.01) {
                    return '${context.tr(AppCopy.theAmountExceedsTheBalance)} (${context.money(remaining)}).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              if (remaining > 0)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () {
                      controller.text = remaining.toStringAsFixed(2);
                    },
                    child: const AppText(AppCopy.payAll),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const AppText(AppCopy.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final v = double.parse(controller.text.trim());
              Navigator.of(context).pop(v);
            },
            child: const AppText(AppCopy.confirmPayment),
          ),
        ],
      ),
    );

    if (amount == null) return;

    try {
      await ref.read(recordContractPaymentProvider)(
        contractId: contract.id!,
        amount: amount,
      );
      await _refreshPayments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText(AppStrings.successSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            context.trError(e),
          ),
        ),
      );
    }
  }

  Future<void> _closeContract(ContractModel contract) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: contract.startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: context.tr(AppCopy.vehicleReturnDate),
    );
    if (date == null) return;

    try {
      // If there's a remaining balance, ask to pay it
      final remaining = contract.remainingAmount;
      if (remaining > 0) {
        if (!mounted) return;
        final payNow = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const AppText(AppCopy.remainingBalance),
            content: AppText(
              context.messages
                  .payBeforeClosing((context.money(remaining)).toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const AppText(AppCopy.noLATER),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const AppText(AppCopy.yesPAYALL),
              ),
            ],
          ),
        );

        if (payNow == true) {
          await ref.read(recordContractPaymentProvider)(
            contractId: contract.id!,
            amount: remaining,
          );
          // Refresh local state before closing
          await _refreshPayments();
        }
      }

      await ref
          .read(contractsProvider.notifier)
          .closeContract(contract.id!, date);
      await ref.read(dashboardProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText(AppStrings.successSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            context.trError(e),
          ),
        ),
      );
    }
  }

  Future<void> _openInspection(int contractId, String type) async {
    await context.push('/contracts/$contractId/inspection/$type');
    if (mounted) ref.invalidate(contractProgressProvider(contractId));
  }

  @override
  Widget build(BuildContext context) {
    final contractsAsync = ref.watch(contractsProvider);
    final contract = contractsAsync.maybeWhen(
      data: (contracts) => _findContract(contracts, widget.contractId),
      orElse: () => null,
    );
    // Watched here too (not just inside _buildActionBar) so the AppBar can
    // decide whether editing is still safe: once a PDF exists for this
    // contract, the persistence layer freezes its terms.
    final progress = contract == null
        ? null
        : ref.watch(contractProgressProvider(widget.contractId)).value;
    final canEdit = contract != null &&
        contract.status != 'completed' &&
        progress?.document == null;

    return Scaffold(
      appBar: AppBar(
        title: const AppText(AppCopy.contract),
        actions: contract == null || contract.status == 'completed'
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: canEdit
                      ? context.tr(AppCopy.editContract)
                      : context.tr(AppCopy.termsAreLockedCreateANewContractTo),
                  onPressed: canEdit
                      ? () => context.push('/contracts/${contract.id}/edit',
                          extra: contract)
                      : null,
                ),
              ],
      ),
      body: BackdropPage(
          child: contractsAsync.when(
        data: (contracts) {
          final contract = _findContract(contracts, widget.contractId);
          if (contract == null) {
            return const EmptyStateWidget(
              title: AppCopy.contractNotFound,
              subtitle: AppCopy.thisContractMayHaveBeenDeleted,
              icon: Icons.receipt_long_outlined,
            );
          }
          return _buildBody(context, contract);
        },
        loading: () => AppShimmer.detailLayer(),
        error: (error, _) => Center(
          child: AppText(
            context.trError(error),
            textAlign: TextAlign.center,
          ),
        ),
      )),
      bottomNavigationBar: contractsAsync.maybeWhen(
        data: (contracts) {
          final contract = _findContract(contracts, widget.contractId);
          return contract == null || contract.status == 'completed'
              ? null
              : _buildActionBar(contract);
        },
        orElse: () => null,
      ),
    );
  }

  /// The departure/return checks are encouraged here, never required to
  /// close: closing a contract was always a one-tap action, at any time —
  /// a stricter build once made it wait on the departure check first, which
  /// took away a working option rather than improving it. `progress == null`
  /// (still loading, or a read that failed) is treated the same as "not done
  /// yet" so Close never silently disappears.
  Widget _buildActionBar(ContractModel contract) {
    final progress =
        ref.watch(contractProgressProvider(widget.contractId)).value;
    final id = contract.id!;
    final departureDone = progress?.departureDone ?? false;
    final returnDone = progress?.returnDone ?? false;

    if (!departureDone) {
      return BottomActionBar(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: () => _openInspection(id, 'departure'),
                icon: const Icon(Icons.key_outlined),
                label: const AppText(AppCopy.pickupInspection),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () => _closeContract(contract),
                icon: const Icon(Icons.lock_outline),
                label: const AppText(AppCopy.closee9f075),
              ),
            ),
          ],
        ),
      );
    }

    return BottomActionBar(
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openInspection(id, 'return'),
              icon: Icon(returnDone
                  ? Icons.check_circle_outline
                  : Icons.assignment_return_outlined),
              label:
                  AppText(returnDone ? AppCopy.returnCompleted : AppCopy.back),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => _closeContract(contract),
              icon: const Icon(Icons.lock_outline),
              label: const AppText(AppCopy.closeContract),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ContractModel contract) {
    final theme = Theme.of(context);
    final lookups = ref.watch(lookupsProvider).value ?? const Lookups();
    final progress = ref.watch(contractProgressProvider(widget.contractId));
    final vehicle = lookups.vehicle(contract.vehicleId);
    final client = lookups.client(contract.primaryDriverId);
    final second = lookups.client(contract.secondaryDriverId);
    final chauffeur = lookups.chauffeur(contract.chauffeurId);
    final ret = returnStatusOf(contract);
    final pay =
        paymentStatusOf(contract, locale: Localizations.localeOf(context));
    final completed = contract.status == 'completed';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(contractProgressProvider(widget.contractId));
        await _refreshPayments();
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          AppCard(
            accent: contract.isLate ? AppTone.danger.color : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Hero(
                        tag: 'contract_${contract.id}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            contract.contractNumber,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ),
                    StatusBadge(text: contract.displayStatus),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 56,
                      child: vehicle == null
                          ? const Icon(Icons.directions_car_filled,
                              color: AppColors.primary, size: 32)
                          : VehiclePhoto(vehicle: vehicle, iconSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              lookups.vehicleNameFor(
                                  context, contract.vehicleId),
                              style: theme.textTheme.titleMedium),
                          if (vehicle != null) ...[
                            const SizedBox(height: 4),
                            PlateBadge(vehicle.registrationNumber),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        client?.fullName ??
                            context.messages.clientNumber(
                                (contract.primaryDriverId).toString()),
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (contract.isLate) ...[
            const SizedBox(height: 12),
            AlertBanner(
              tone: AppTone.danger,
              icon: Icons.schedule,
              title: ret.label,
              message: context.messages.returnWasDue(
                  (_dateFormatter.format(contract.expectedReturnDate))
                      .toString()),
            ),
          ] else if (completed && contract.remainingAmount > 0.009) ...[
            const SizedBox(height: 12),
            AlertBanner(
              tone: AppTone.warning,
              title: AppCopy.unpaidBalance,
              message: context.messages.completedContractBalance(
                  (context.money(contract.remainingAmount)).toString()),
            ),
          ],
          if (!completed) ...[
            const SectionHeader(
              title: AppCopy.rentalTracking,
              padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: progress.when(
                data: (p) => DetailList(children: [
                  _StepRow(
                    done: p.departureDone,
                    title: AppCopy.pickupInspectiondc5650,
                    subtitle: p.departure == null
                        ? AppCopy.completeBeforeHandingOverTheKeys
                        : context.messages.completedOn(
                            (_dateFormatter.format(p.departure!.createdAt))
                                .toString()),
                    onTap: () => _openInspection(contract.id!, 'departure'),
                  ),
                  _StepRow(
                    done: p.signed,
                    title: AppCopy.signedContract,
                    subtitle: p.signed
                        ? AppCopy.signedPDFSaved
                        : AppCopy.toBeSignedByTheClientSeeBelow,
                  ),
                  _StepRow(
                    done: pay.isSettled,
                    title: AppCopy.payment,
                    subtitle: pay.isSettled
                        ? AppCopy.contractPaidInFull
                        : context.messages.balanceToCollect(
                            (context.money(contract.remainingAmount))
                                .toString()),
                  ),
                  _StepRow(
                    done: p.returnDone,
                    title: AppCopy.returnInspection,
                    subtitle: p.returned == null
                        ? ret.label
                        : context.messages.completedOn(
                            (_dateFormatter.format(p.returned!.createdAt))
                                .toString()),
                    onTap: () => _openInspection(contract.id!, 'return'),
                  ),
                ]),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: AppText(AppCopy.trackingIsUnavailableAtTheMoment),
                ),
              ),
            ),
          ],
          const SectionHeader(
            title: AppCopy.rentalPeriod,
            padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DetailList(children: [
              DetailRow(
                icon: Icons.flag_outlined,
                label: AppCopy.pickup,
                value: _dateFormatter.format(contract.startDate),
              ),
              DetailRow(
                icon: Icons.event_outlined,
                label: AppCopy.expectedReturn,
                value: _dateFormatter.format(contract.expectedReturnDate),
                trailing: completed
                    ? null
                    : StatusChip(label: ret.label, tone: ret.tone, dense: true),
              ),
              if (contract.actualReturnDate != null)
                DetailRow(
                  icon: Icons.assignment_turned_in_outlined,
                  label: AppCopy.actualReturn,
                  value: _dateFormatter.format(contract.actualReturnDate!),
                ),
              DetailRow(
                icon: Icons.timelapse,
                label: AppCopy.duration,
                value: context.messages.rentalDays(
                    (contract.rentalDays < 1 ? 1 : contract.rentalDays)
                        .toString()),
              ),
            ]),
          ),
          const SectionHeader(
            title: AppCopy.clientAndDrivers,
            padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DetailList(children: [
              DetailRow(
                icon: Icons.person_outline,
                label: AppCopy.mainDriver,
                value: client?.fullName ??
                    context.messages
                        .clientNumber((contract.primaryDriverId).toString()),
                trailing: client == null
                    ? null
                    : Text(client.phone,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                onTap: client == null || client.id == null
                    ? null
                    : () => context.push('/clients/${client.id}'),
              ),
              if (contract.secondaryDriverId != null)
                DetailRow(
                  icon: Icons.person_add_alt_outlined,
                  label: AppCopy.additionalDriver,
                  value: second?.fullName ??
                      context.messages.clientNumber(
                          (contract.secondaryDriverId).toString()),
                  onTap: second == null || second.id == null
                      ? null
                      : () => context.push('/clients/${second.id}'),
                ),
              if (contract.chauffeurId != null)
                DetailRow(
                  icon: Icons.badge_outlined,
                  label: AppCopy.agencyDriver,
                  value: chauffeur?.fullName ??
                      context.messages
                          .driverNumber((contract.chauffeurId).toString()),
                  trailing: AppText(
                    context.messages.hourlyDriverCost(
                        (contract.chauffeurHours.toStringAsFixed(
                                contract.chauffeurHours % 1 == 0 ? 0 : 1))
                            .toString(),
                        (context.money(contract.chauffeurHourlyRate))
                            .toString()),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ]),
          ),
          const SectionHeader(
            title: AppCopy.payments,
            padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          _buildPayments(context, contract, pay),
          const SectionHeader(
            title: AppCopy.pdfAndSignature,
            padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          ContractSignatureCard(
            key: ValueKey(contract.id),
            contractId: contract.id!,
            onChanged: () =>
                ref.invalidate(contractProgressProvider(widget.contractId)),
          ),
          if ((contract.notes ?? '').trim().isNotEmpty) ...[
            const SectionHeader(
              title: AppCopy.notes,
              padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
            ),
            AppCard(child: Text(contract.notes!.trim())),
          ],
          if (completed) ...[
            const SectionHeader(
              title: AppCopy.inspections,
              padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DetailList(children: [
                DetailRow(
                  icon: Icons.departure_board_outlined,
                  label: AppCopy.pickup,
                  value: context.tr(AppCopy.viewOrRedo),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openInspection(contract.id!, 'departure'),
                ),
                DetailRow(
                  icon: Icons.assignment_return_outlined,
                  label: AppCopy.back,
                  value: context.tr(AppCopy.viewOrRedo),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openInspection(contract.id!, 'return'),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _deleteContract(contract),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTone.danger.color,
              side: BorderSide(color: AppTone.danger.color),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const AppText(AppCopy.deleteThisContract893d83),
          ),
        ],
      ),
    );
  }

  /// Reachable at any status, not just completed — the operator can create a
  /// contract by mistake and needs a way out that doesn't involve waiting for
  /// the rental period to run its course.
  Future<void> _deleteContract(ContractModel contract) async {
    final confirmed = await confirmDeleteContract(context, contract);
    if (!confirmed || !mounted) return;
    try {
      await ref.read(contractsProvider.notifier).deleteContract(contract.id!);
      await ref.read(dashboardProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText(AppCopy.contractDeletedSuccessfully)),
      );
      context.go('/contracts');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(context.trError(e))),
      );
    }
  }

  Widget _buildPayments(
    BuildContext context,
    ContractModel contract,
    PaymentStatus pay,
  ) {
    final theme = Theme.of(context);
    final ratio = contract.totalPrice <= 0
        ? 1.0
        : (contract.amountPaid / contract.totalPrice).clamp(0.0, 1.0);

    Widget figure(String label, double value, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: AppText(
                  context.money(value),
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              figure('Total', contract.totalPrice),
              figure(AppCopy.paidfa02fd, contract.amountPaid,
                  color: AppTone.success.color),
              figure('Reste', contract.remainingAmount,
                  color: pay.isSettled
                      ? AppColors.textSecondary
                      : AppTone.danger.color),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: AppTone.neutral.soft,
              color: pay.isSettled ? AppTone.success.color : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          ref.watch(contractPaymentHistoryProvider(widget.contractId)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppText(context.trError(error)),
                data: (payments) {
                  if (payments.isEmpty) {
                    return AppText(
                      AppCopy.noPaymentsRecordedForThisContract,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    );
                  }
                  return CollapsibleSection(
                    wrapInCard: false,
                    icon: Icons.receipt_long_outlined,
                    title: AppCopy.paymentHistory,
                    subtitle: context.messages
                        .paymentCount((payments.length).toString()),
                    badge: StatusChip(
                      label: '${payments.length}',
                      tone: AppTone.info,
                      dense: true,
                    ),
                    children: [
                      for (final payment in payments)
                        DetailRow(
                          icon: Icons.payments_outlined,
                          label: _dateFormatter.format(payment.paidAt),
                          value: context.money(payment.amount),
                        ),
                    ],
                  );
                },
              ),
          if (contract.status != 'completed') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: pay.isSettled ? null : () => _addPayment(contract),
              icon: const Icon(Icons.add),
              label: const AppText(AppCopy.recordPayment),
            ),
          ],
        ],
      ),
    );
  }

  ContractModel? _findContract(List<ContractModel>? list, int id) {
    if (list == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.done,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final bool done;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? AppTone.success.color : const Color(0xFF9AA3B5),
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(title,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    AppText(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
