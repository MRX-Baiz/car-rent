import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/models/contract_model.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/dashboard/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardProvider);
    final companyNameAsync = ref.watch(companyNameProvider);
    final contractsAsync = ref.watch(contractsProvider);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return AdaptiveLayout(
      child: Scaffold(
        appBar: AppBar(
          title: companyNameAsync.when(
            data: (name) => Text(name.isNotEmpty ? name : 'CarRent Manager'),
            loading: () => const Text('CarRent Manager'),
            error: (_, __) => const Text('CarRent Manager'),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: statsAsync.when(
            data: (stats) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tableau de bord',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      final children = [
                        StatCard(
                          title: 'Véhicules disponibles',
                          value: stats.availableVehicles.toString(),
                          icon: Icons.directions_car,
                          color: const Color(0xFF4CAF50),
                        ),
                        StatCard(
                          title: 'Véhicules loués',
                          value: stats.rentedVehicles.toString(),
                          icon: Icons.directions_car_filled,
                          color: const Color(0xFFFF9800),
                        ),
                        StatCard(
                          title: 'Contrats actifs',
                          value: stats.activeContracts.toString(),
                          icon: Icons.receipt_long,
                          color: const Color(0xFF2196F3),
                        ),
                        StatCard(
                          title: 'Contrats en retard',
                          value: stats.lateContracts.toString(),
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFD32F2F),
                        ),
                      ];

                      if (isWide) {
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: children
                              .map(
                                (c) => SizedBox(
                                  width: (constraints.maxWidth - 48) / 2,
                                  child: c,
                                ),
                              )
                              .toList(),
                        );
                      } else {
                        return Column(
                          children: children
                              .map(
                                (c) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: c,
                                ),
                              )
                              .toList(),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Contrats récents',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go('/contracts'),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Voir tout'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: contractsAsync.when(
                      data: (contracts) {
                        final recent = contracts.take(5).toList();
                        if (recent.isEmpty) {
                          return Center(
                            child: Text(
                              'Aucun contrat pour le moment.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: recent.length,
                          itemBuilder: (context, index) {
                            final c = recent[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                onTap: () {
                                  if (c.id != null) {
                                    context.go('/contracts/${c.id}');
                                  }
                                },
                                title: Text(
                                  c.contractNumber,
                                  style: theme.textTheme.titleSmall,
                                ),
                                subtitle: Text(
                                  '${dateFormat.format(c.startDate)} → ${dateFormat.format(c.expectedReturnDate)} · '
                                  '${c.remainingAmount.toStringAsFixed(0)} MAD restants',
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: StatusBadge(text: c.status),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (_, __) => Center(
                        child: Text(
                          'Impossible de charger les contrats.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Erreur lors du chargement du tableau de bord.\n'
                'خطأ أثناء تحميل لوحة التحكم.\n'
                'Dashboard loading error: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/contracts/new'),
          icon: const Icon(Icons.add),
          label: const Text('Nouveau contrat'),
        ),
      ),
    );
  }
}

