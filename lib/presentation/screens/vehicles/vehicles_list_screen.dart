import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/storage/media_store.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/app_shimmer.dart';

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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
            tooltip: 'Retour',
          ),
          title: const Text('Véhicules'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final searchField = TextField(
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
                  );

                  // Scrolls sideways when the chips are wider than the screen,
                  // instead of overflowing and squeezing the search field.
                  final filterChips = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in const [
                          ('Tous', 'all'),
                          ('Disponibles', 'available'),
                          ('Loués', 'rented'),
                          ('Maintenance', 'maintenance'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ChoiceChip(
                              label: Text(filter.$1),
                              selected: _statusFilter == filter.$2,
                              onSelected: (_) {
                                setState(() {
                                  _statusFilter = filter.$2;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  );

                  // Side by side only when there is room for both.
                  if (constraints.maxWidth > 700) {
                    return Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 8),
                        Flexible(child: filterChips),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      filterChips,
                    ],
                  );
                },
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
                                  context.push('/vehicles/${vehicle.id}');
                                }
                              },
                              leading: Hero(
                                tag: 'vehicle_${vehicle.id}',
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: vehicle.imageBytes != null
                                      ? Image.memory(
                                          vehicle.imageBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : (MediaStore.instance
                                                  .resolveFile(vehicle.imagePath) !=
                                              null
                                          ? Image.file(
                                              MediaStore.instance
                                                  .resolveFile(vehicle.imagePath)!,
                                              fit: BoxFit.cover,
                                            )
                                          : Icon(
                                              Icons.directions_car_filled,
                                              color: theme.colorScheme.primary,
                                            )),
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
                loading: () => AppShimmer.listLayer(),
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
          onPressed: () => context.push('/vehicles/add'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

