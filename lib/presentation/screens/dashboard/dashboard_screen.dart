import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import '../../providers/app_settings_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/client_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/dashboard/revenue_chart.dart';
import '../../widgets/common/global_search_delegate.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/dashboard/stat_card.dart';
import '../../../core/ocr/ocr_service.dart';

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
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: const Color(0xFFB9AFA6).withValues(alpha: 0.85)),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/license'),
            tooltip: 'Retour',
          ),
          title: companyNameAsync.when(
            data: (name) => Text(
              name.isNotEmpty ? name : 'CarRent Manager',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            loading: () => const Text('CarRent Manager'),
            error: (_, __) => const Text('CarRent Manager'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => showSearch(
                context: context,
                delegate: GlobalSearchDelegate(ref),
              ),
              tooltip: 'Recherche globale',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 110, 16, 16),
          children: [
            Text(
              'Bonjour 👋',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Voici un aperçu de votre activité aujourd\'hui.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Statistics Grid with Glassmorphism-lite
            statsAsync.when(
              data: (stats) => LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final children = [
                    StatCard(
                      title: 'Véhicules dispo.',
                      value: stats.availableVehicles.toString(),
                      icon: Icons.directions_car,
                      color: const Color(0xFF4CAF50),
                      onTap: () => context.go('/vehicles'),
                    ),
                    StatCard(
                      title: 'En location',
                      value: stats.rentedVehicles.toString(),
                      icon: Icons.directions_car_filled,
                      color: const Color(0xFFFF9800),
                      onTap: () => context.go('/vehicles'),
                    ),
                    StatCard(
                      title: 'Contrats actifs',
                      value: stats.activeContracts.toString(),
                      icon: Icons.receipt_long,
                      color: const Color(0xFF2196F3),
                      onTap: () => context.go('/contracts'),
                    ),
                    StatCard(
                      title: 'En retard',
                      value: stats.lateContracts.toString(),
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFD32F2F),
                      onTap: () => context.go('/contracts'),
                    ),
                  ];

                  // A fixed aspect ratio ties card height to column width, so
                  // narrow screens or a large system font clipped the labels.
                  // Giving the row an explicit height keeps content intact.
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(1.0);
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isWide ? 4 : 2,
                    // Tall enough for a two-line label plus the value; a
                    // shorter cell clips them on narrow screens.
                    mainAxisExtent: 118 * textScale.clamp(1.0, 1.6),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: children,
                  );
                },
              ),
              loading: () => AppShimmer.statsGrid(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Revenue Section
            Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tendances des revenus (7j)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            statsAsync.when(
              data: (stats) => RevenueChart(data: stats.weeklyRevenue),
              loading: () => const AppShimmer.rectangular(height: 200),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Actions rapides',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildQuickActionGrid(context),

            const SizedBox(height: 24),

            // Recent Contracts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contrats récents',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/contracts'),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            contractsAsync.when(
              data: (contracts) {
                final recent = contracts.take(5).toList();
                if (recent.isEmpty) {
                  return const Center(child: Text('Aucun contrat récent.'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recent.length,
                  itemBuilder: (context, index) {
                    final c = recent[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Hero(
                          tag: 'contract_${c.id}',
                          child: const Icon(Icons.receipt_long),
                        ),
                        title: Text(c.contractNumber),
                        subtitle: Text(
                          '${dateFormat.format(c.startDate)} · ${c.remainingAmount.toInt()} MAD restant',
                        ),
                        trailing: StatusBadge(text: c.status),
                        onTap: () => context.push('/contracts/${c.id}'),
                      ),
                    );
                  },
                );
              },
              loading: () => AppShimmer.listLayer(itemCount: 3),
              error: (_, __) => const Text('Erreur de chargement des contrats.'),
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/contracts/new'),
          icon: const Icon(Icons.add),
          label: const Text('Nouveau contrat'),
        ),
      ),
    );
  }

  Widget _buildQuickActionGrid(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisExtent: 92 * textScale.clamp(1.0, 1.6),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _QuickActionCard(
          icon: Icons.person_add_outlined,
          label: 'Client',
          onTap: () => context.push('/clients/add'),
        ),
        _QuickActionCard(
          icon: Icons.directions_car_outlined,
          label: 'Véhicule',
          onTap: () => context.push('/vehicles/add'),
        ),
        _QuickActionCard(
          icon: Icons.receipt_long_outlined,
          label: 'Contrat',
          onTap: () => context.push('/contracts/new'),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

