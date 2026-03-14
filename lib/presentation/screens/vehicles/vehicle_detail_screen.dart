import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/models/vehicle_model.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/status_badge.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({
    super.key,
    required this.vehicleId,
  });

  final int vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du véhicule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              final vehicle = _findVehicle(vehiclesAsync.value, vehicleId);
              if (vehicle != null) {
                context.go('/vehicles/$vehicleId/edit', extra: vehicle);
              }
            },
          ),
        ],
      ),
      body: vehiclesAsync.when(
        data: (vehicles) {
          final vehicle = _findVehicle(vehicles, vehicleId);
          if (vehicle == null) {
            return const EmptyStateWidget(
              title: 'Véhicule introuvable.',
              subtitle: 'Ce véhicule a peut-être été supprimé.',
              icon: Icons.directions_car_filled_outlined,
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 160,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surfaceVariant,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: vehicle.imagePath != null
                              ? Image.file(
                                  File(vehicle.imagePath!),
                                  fit: BoxFit.cover,
                                )
                              : Icon(
                                  Icons.directions_car_filled,
                                  size: 64,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${vehicle.brand} ${vehicle.model}',
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  StatusBadge(text: vehicle.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                vehicle.registrationNumber,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Année ${vehicle.year}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${vehicle.dailyPrice.toStringAsFixed(2)} MAD / jour',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Informations système',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID interne: ${vehicle.id ?? '-'}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Créé le: ${vehicle.createdAt.toIso8601String()}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mis à jour le: ${vehicle.updatedAt.toIso8601String()}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer le véhicule'),
                                content: const Text(
                                  AppStrings.confirmDeleteVehicle,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;

                            try {
                              if (vehicle.id != null) {
                                await ref
                                    .read(vehiclesProvider.notifier)
                                    .deleteVehicle(vehicle.id!);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(AppStrings.successDeleted),
                                  ),
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
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Erreur lors du chargement du véhicule.\n'
            'خطأ أثناء تحميل السيارة.\n'
            'Vehicle loading error: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  VehicleModel? _findVehicle(List<VehicleModel>? list, int id) {
    if (list == null) return null;
    try {
      return list.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }
}

