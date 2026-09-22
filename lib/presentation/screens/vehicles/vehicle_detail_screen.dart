import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/vehicle_labels.dart';
import '../../../core/utils/vehicle_maintenance.dart';
import '../../../data/models/vehicle_model.dart';
import '../../providers/lookup_provider.dart';
import '../../providers/vehicle_provider.dart';
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
        title: const Text('Véhicule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier le véhicule',
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
            label: const Text('Louer ce véhicule'),
          ),
        );
      }(),
      body: BackdropPage(
          child: vehiclesAsync.when(
        data: (vehicles) {
          final vehicle = _findVehicle(vehicles, vehicleId);
          if (vehicle == null) {
            return const EmptyStateWidget(
              title: 'Véhicule introuvable.',
              subtitle: 'Ce véhicule a peut-être été supprimé.',
              icon: Icons.directions_car_filled_outlined,
            );
          }
          return _Body(
              vehicle: vehicle, onDelete: () => _delete(context, ref, vehicle));
        },
        loading: () => AppShimmer.detailLayer(),
        error: (error, _) => Center(
          child: Text(
            'Erreur lors du chargement du véhicule.\n'
            'خطأ أثناء تحميل السيارة.\n'
            'Vehicle loading error: $error',
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
        title: const Text('Supprimer le véhicule'),
        content: const Text(AppStrings.confirmDeleteVehicle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTone.danger.color),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
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
          const SnackBar(content: Text(AppStrings.successDeleted)),
        );
        context.go('/vehicles');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la suppression.\n'
            'حدث خطأ أثناء الحذف.\n'
            'Delete error: $e',
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
                            Text('Année ${vehicle.year}',
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
                      ? '1 point à traiter'
                      : '${alerts.length} points à traiter',
                  message: alerts
                      .map((a) => '${a.label} : ${a.status.toLowerCase()}')
                      .join('\n'),
                ),
              ],
              const SectionHeader(
                title: 'Informations du véhicule',
                padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MetricGrid(items: [
                      MetricItem(Icons.speed_outlined, 'Kilométrage',
                          formatKm(vehicle.currentMileage)),
                      MetricItem(fuelTypeIcon(vehicle.fuelType), 'Carburant',
                          fuelTypeName(vehicle.fuelType)),
                      MetricItem(Icons.local_gas_station_outlined,
                          'Niveau de carburant', '${vehicle.fuelLevel} %'),
                      MetricItem(Icons.settings_outlined, 'Boîte',
                          transmissionName(vehicle.transmission)),
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('État général',
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
                title: 'Photos et dégâts',
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
                          Text('Photos extérieures et dégâts',
                              style: theme.textTheme.titleSmall),
                          Text(
                            'Avant, arrière, côtés et dégâts existants.',
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
                  title: 'Entretien et documents légaux',
                  subtitle: alerts.isEmpty
                      ? 'À jour'
                      : '${alerts.length} '
                          '${alerts.length > 1 ? 'points' : 'point'} à surveiller',
                  badge: StatusChip(
                    label: alerts.isEmpty ? 'À jour' : '${alerts.length}',
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
                        value: item.value,
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
              SectionHeader(
                title: 'Historique de location',
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                actionLabel: 'Tous les contrats',
                onAction: () => context.go('/contracts'),
              ),
              if (history == null)
                const SizedBox.shrink()
              else
                history.when(
                  data: (contracts) => contracts.isEmpty
                      ? AppCard(
                          child: Text(
                            'Ce véhicule n’a pas encore été loué.',
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
                      const Text('Historique indisponible pour le moment.'),
                ),
              const SizedBox(height: 16),
              Text(
                'Ajouté le ${formatDate(vehicle.createdAt)} · '
                'modifié le ${formatDate(vehicle.updatedAt)}',
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
                label: const Text('Supprimer ce véhicule'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
