import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/contract_insights.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/contract_model.dart';
import '../../providers/lookup_provider.dart';
import '../common/app_card.dart';
import '../common/status_badge.dart';
import '../common/status_chip.dart';
import '../common/vehicle_photo.dart';

/// One rental at a glance: which car, who has it, when it comes back, and
/// whether it is paid. Late rentals get a red edge so they read first.
class ContractCard extends StatelessWidget {
  const ContractCard({
    super.key,
    required this.contract,
    required this.lookups,
    this.onTap,
    this.onDelete,
    this.compact = false,
  });

  final ContractModel contract;
  final Lookups lookups;
  final VoidCallback? onTap;

  /// Only offered for closed contracts; shown as a trailing icon button.
  final VoidCallback? onDelete;

  /// Drops the dates and payment row; used where space is short (dashboard).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicle = lookups.vehicle(contract.vehicleId);
    final client = lookups.client(contract.primaryDriverId);
    final ret = returnStatusOf(contract);
    final pay = paymentStatusOf(contract);
    final late = contract.displayStatus == 'late';
    final chauffeur = lookups.chauffeur(contract.chauffeurId);

    return AppCard(
      onTap: onTap,
      accent: late ? AppTone.danger.color : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: compact ? 48 : 56,
                height: compact ? 48 : 56,
                child: vehicle == null
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius:
                                BorderRadius.all(Radius.circular(12))),
                        child: Icon(Icons.directions_car_filled,
                            color: AppColors.primary),
                      )
                    : VehiclePhoto(vehicle: vehicle, iconSize: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lookups.vehicleName(contract.vehicleId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      [
                        if (vehicle != null) vehicle.registrationNumber,
                        if (!compact) contract.contractNumber,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (compact)
                Flexible(
                  flex: 0,
                  child:
                      StatusChip(label: ret.label, tone: ret.tone, dense: true),
                )
              else
                StatusBadge(text: contract.displayStatus),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Supprimer le contrat',
                  icon: Icon(Icons.delete_outline, color: AppTone.danger.color),
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _Line(
            icon: Icons.person_outline,
            text: client?.fullName ?? 'Client #${contract.primaryDriverId}',
            trailing: chauffeur == null ? null : 'Chauffeur',
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            _Line(
              icon: Icons.event_outlined,
              text: '${formatDate(contract.startDate)}  →  '
                  '${formatDate(contract.expectedReturnDate)}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusChip(
                    label: ret.label,
                    tone: ret.tone,
                    icon: contract.status == 'completed'
                        ? Icons.task_alt
                        : Icons.schedule),
                StatusChip(
                    label: pay.label,
                    tone: pay.tone,
                    icon: pay.isSettled
                        ? Icons.check_circle_outline
                        : Icons.payments_outlined),
              ],
            ),
          ] else if (!pay.isSettled) ...[
            const SizedBox(height: 6),
            _Line(
                icon: Icons.payments_outlined,
                text: 'Reste ${formatMad(contract.remainingAmount)}'),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.trailing});
  final IconData icon;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium),
        ),
        if (trailing != null)
          StatusChip(label: trailing!, icon: Icons.badge_outlined, dense: true),
      ],
    );
  }
}
