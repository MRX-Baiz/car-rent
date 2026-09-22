import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/contract_insights.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/contract_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../../data/repositories/payment_repository.dart';
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
  final PaymentRepository _paymentRepository = PaymentRepository.instance;

  late Future<List<PaymentModel>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _paymentsFuture =
        _paymentRepository.getPaymentsByContractId(widget.contractId);
  }

  Future<void> _refreshPayments() async {
    setState(() {
      _paymentsFuture =
          _paymentRepository.getPaymentsByContractId(widget.contractId);
    });
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
        title: const Text('Ajouter un paiement'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reste à payer : ${formatMad(remaining)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Montant à payer',
                  suffixText: 'MAD',
                  helperText: 'Saisissez le montant versé par le client.',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le montant est requis.';
                  }
                  final v = double.tryParse(value);
                  if (v == null || v <= 0) {
                    return 'Montant invalide.';
                  }
                  if (v > remaining + 0.01) {
                    return 'Le montant dépasse le reste (${formatMad(remaining)}).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              if (remaining > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      controller.text = remaining.toStringAsFixed(2);
                    },
                    child: const Text('Tout payer'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final v = double.parse(controller.text.trim());
              Navigator.of(context).pop(v);
            },
            child: const Text('Valider le paiement'),
          ),
        ],
      ),
    );

    if (amount == null) return;

    try {
      await ContractRepository.instance
          .addPaymentAndUpdateContract(contract.id!, amount);
      await _refreshPayments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l’ajout du paiement.\n'
            'Payment error: $e',
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
      helpText: 'Date de retour du véhicule',
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
            title: const Text('Reste à payer'),
            content: Text(
              'Il reste ${formatMad(remaining)} à payer. '
              'Voulez-vous enregistrer ce paiement avant la clôture ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('NON, PLUS TARD'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('OUI, PAYER TOUT'),
              ),
            ],
          ),
        );

        if (payNow == true) {
          await ContractRepository.instance
              .addPaymentAndUpdateContract(contract.id!, remaining);
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
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la clôture du contrat.\n'
            'حدث خطأ أثناء إغلاق العقد.\n'
            'Close contract error: $e',
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
    // contract, ContractRepository.updateContract freezes its terms.
    final progress = contract == null
        ? null
        : ref.watch(contractProgressProvider(widget.contractId)).value;
    final canEdit = contract != null &&
        contract.status != 'completed' &&
        progress?.document == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrat'),
        actions: contract == null || contract.status == 'completed'
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: canEdit
                      ? 'Modifier le contrat'
                      : 'Conditions figées — créez un nouveau contrat pour '
                          'les modifier',
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
              title: 'Contrat introuvable.',
              subtitle: 'Ce contrat a peut-être été supprimé.',
              icon: Icons.receipt_long_outlined,
            );
          }
          return _buildBody(context, contract);
        },
        loading: () => AppShimmer.detailLayer(),
        error: (error, _) => Center(
          child: Text(
            'Erreur lors du chargement du contrat.\n'
            'خطأ أثناء تحميل العقد.\n'
            'Contract loading error: $error',
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
                label: const Text('État des lieux départ'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () => _closeContract(contract),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Clôturer'),
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
              label: Text(returnDone ? 'Retour fait' : 'Retour'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => _closeContract(contract),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Clôturer le contrat'),
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
    final pay = paymentStatusOf(contract);
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
                          Text(lookups.vehicleName(contract.vehicleId),
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
                            'Client #${contract.primaryDriverId}',
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
              message: 'Le retour était prévu le '
                  '${_dateFormatter.format(contract.expectedReturnDate)}.',
            ),
          ] else if (completed && contract.remainingAmount > 0.009) ...[
            const SizedBox(height: 12),
            AlertBanner(
              tone: AppTone.warning,
              title: 'Solde impayé',
              message: 'Il reste ${formatMad(contract.remainingAmount)} '
                  'à encaisser sur ce contrat terminé.',
            ),
          ],
          if (!completed) ...[
            const SectionHeader(
              title: 'Suivi de la location',
              padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: progress.when(
                data: (p) => DetailList(children: [
                  _StepRow(
                    done: p.departureDone,
                    title: 'État des lieux de départ',
                    subtitle: p.departure == null
                        ? 'À faire avant la remise des clés.'
                        : 'Fait le ${_dateFormatter.format(p.departure!.createdAt)}',
                    onTap: () => _openInspection(contract.id!, 'departure'),
                  ),
                  _StepRow(
                    done: p.signed,
                    title: 'Contrat signé',
                    subtitle: p.signed
                        ? 'PDF signé enregistré.'
                        : 'À signer par le client (voir plus bas).',
                  ),
                  _StepRow(
                    done: pay.isSettled,
                    title: 'Paiement',
                    subtitle: pay.isSettled
                        ? 'Contrat entièrement payé.'
                        : 'Reste ${formatMad(contract.remainingAmount)} à encaisser.',
                  ),
                  _StepRow(
                    done: p.returnDone,
                    title: 'État des lieux de retour',
                    subtitle: p.returned == null
                        ? ret.label
                        : 'Fait le ${_dateFormatter.format(p.returned!.createdAt)}',
                    onTap: () => _openInspection(contract.id!, 'return'),
                  ),
                ]),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Suivi indisponible pour le moment.'),
                ),
              ),
            ),
          ],
          const SectionHeader(
            title: 'Période de location',
            padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DetailList(children: [
              DetailRow(
                icon: Icons.flag_outlined,
                label: 'Départ',
                value: _dateFormatter.format(contract.startDate),
              ),
              DetailRow(
                icon: Icons.event_outlined,
                label: 'Retour prévu',
                value: _dateFormatter.format(contract.expectedReturnDate),
                trailing: completed
                    ? null
                    : StatusChip(label: ret.label, tone: ret.tone, dense: true),
              ),
              if (contract.actualReturnDate != null)
                DetailRow(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'Retour réel',
                  value: _dateFormatter.format(contract.actualReturnDate!),
                ),
              DetailRow(
                icon: Icons.timelapse,
                label: 'Durée',
                value:
                    '${contract.rentalDays < 1 ? 1 : contract.rentalDays} jour(s)',
              ),
            ]),
          ),
          const SectionHeader(
            title: 'Client et conducteurs',
            padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DetailList(children: [
              DetailRow(
                icon: Icons.person_outline,
                label: 'Conducteur principal',
                value:
                    client?.fullName ?? 'Client #${contract.primaryDriverId}',
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
                  label: 'Conducteur secondaire',
                  value: second?.fullName ??
                      'Client #${contract.secondaryDriverId}',
                  onTap: second == null || second.id == null
                      ? null
                      : () => context.push('/clients/${second.id}'),
                ),
              if (contract.chauffeurId != null)
                DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Chauffeur de l’agence',
                  value: chauffeur?.fullName ??
                      'Chauffeur #${contract.chauffeurId}',
                  trailing: Text(
                    '${contract.chauffeurHours.toStringAsFixed(contract.chauffeurHours % 1 == 0 ? 0 : 1)} h × '
                    '${formatMad(contract.chauffeurHourlyRate)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ]),
          ),
          const SectionHeader(
            title: 'Paiements',
            padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          _buildPayments(context, contract, pay),
          const SectionHeader(
            title: 'PDF et signature',
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
              title: 'Notes',
              padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
            ),
            AppCard(child: Text(contract.notes!.trim())),
          ],
          if (completed) ...[
            const SectionHeader(
              title: 'États des lieux',
              padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DetailList(children: [
                DetailRow(
                  icon: Icons.departure_board_outlined,
                  label: 'Départ',
                  value: 'Voir ou refaire',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openInspection(contract.id!, 'departure'),
                ),
                DetailRow(
                  icon: Icons.assignment_return_outlined,
                  label: 'Retour',
                  value: 'Voir ou refaire',
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
            label: const Text('Supprimer ce contrat'),
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
        const SnackBar(content: Text('Contrat supprimé avec succès.')),
      );
      context.go('/contracts');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression : $e')),
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
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMad(value),
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
              figure('Payé', contract.amountPaid, color: AppTone.success.color),
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
          FutureBuilder<List<PaymentModel>>(
            future: _paymentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'Erreur lors du chargement des paiements.\n'
                  'خطأ أثناء تحميل الأداءات.\n'
                  'Payments loading error: ${snapshot.error}',
                );
              }
              final payments = snapshot.data ?? [];
              if (payments.isEmpty) {
                return Text(
                  'Aucun paiement enregistré pour ce contrat.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                );
              }
              return CollapsibleSection(
                wrapInCard: false,
                icon: Icons.receipt_long_outlined,
                title: 'Historique des paiements',
                subtitle: '${payments.length} '
                    'versement${payments.length > 1 ? 's' : ''}',
                badge: StatusChip(
                    label: '${payments.length}',
                    tone: AppTone.info,
                    dense: true),
                children: [
                  for (final p in payments)
                    DetailRow(
                      icon: Icons.payments_outlined,
                      label: _dateFormatter.format(p.paymentDate),
                      value: formatMad(p.amount),
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
              label: const Text('Enregistrer un paiement'),
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
                    Text(title,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle,
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
