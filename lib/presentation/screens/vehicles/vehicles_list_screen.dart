import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/status_badge.dart';

class VehiclesListScreen extends ConsumerStatefulWidget {
  const VehiclesListScreen({super.key});

  @override
  ConsumerState<VehiclesListScreen> createState() =>
      _VehiclesListScreenState();
}

class _VehiclesListScreenState extends ConsumerState<VehiclesListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(vehiclesProvider.notifier).loadVehicles(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final theme = Theme.of(context);

    return AdaptiveLayout(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Véhicules'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText:
                            'Rechercher par marque, modèle ou immatriculation',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('Tous'),
                        selected: _statusFilter == 'all',
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = 'all';
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Disponibles'),
                        selected: _statusFilter == 'available',
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = 'available';
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Loués'),
                        selected: _statusFilter == 'rented',
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = 'rented';
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Maintenance'),
                        selected: _statusFilter == 'maintenance',
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = 'maintenance';
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: vehiclesAsync.when(
                data: (vehicles) {
                  final filtered = vehicles.where((v) {
                    if (_statusFilter != 'all' && v.status != _statusFilter) {
                      return false;
                    }
                    if (_searchQuery.isEmpty) return true;
                    final q = _searchQuery;
                    return v.brand.toLowerCase().contains(q) ||
                        v.model.toLowerCase().contains(q) ||
                        v.registrationNumber.toLowerCase().contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'Aucun véhicule trouvé.',
                      subtitle:
                          'Ajoutez un nouveau véhicule ou modifiez vos filtres.',
                      icon: Icons.directions_car_filled_outlined,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(vehiclesProvider.notifier).loadVehicles(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final vehicle = filtered[index];
                        return Dismissible(
                          key: ValueKey(vehicle.id ?? index),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: theme.colorScheme.error,
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(
                              Icons.delete_forever,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
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
                            return confirmed ?? false;
                          },
                          onDismissed: (_) async {
                            try {
                              if (vehicle.id != null) {
                                await ref
                                    .read(vehiclesProvider.notifier)
                                    .deleteVehicle(vehicle.id!);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(AppStrings.successDeleted),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
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
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              onTap: () {
                                if (vehicle.id != null) {
                                  context.go('/vehicles/${vehicle.id}');
                                }
                              },
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.primary.withOpacity(0.1),
                                child: Icon(
                                  Icons.directions_car_filled,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              title: Text('${vehicle.brand} ${vehicle.model}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle.registrationNumber,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${vehicle.dailyPrice.toStringAsFixed(2)} MAD / jour',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: StatusBadge(text: vehicle.status),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Erreur lors du chargement des véhicules.\n'
                    'خطأ أثناء تحميل السيارات.\n'
                    'Vehicles loading error: $error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.go('/vehicles/add'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

