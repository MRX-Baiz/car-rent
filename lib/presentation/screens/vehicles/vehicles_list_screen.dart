import 'package:flutter/material.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/license/license_features.dart';
import '../../../core/license/license_manager.dart';
import '../../../core/utils/contract_insights.dart';
import '../../../core/utils/vehicle_labels.dart';
import '../../../core/utils/vehicle_maintenance.dart';
import '../../../data/models/vehicle_model.dart';
import '../../providers/contract_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/plate_badge.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/common/vehicle_photo.dart';
import '../../widgets/motion/motion.dart';

/// The near-black the Vehicles page is built on; it matches the artwork.
const _pageDark = Color(0xFF0A0B0F);

class VehiclesListScreen extends ConsumerStatefulWidget {
  const VehiclesListScreen({super.key});

  @override
  ConsumerState<VehiclesListScreen> createState() => _VehiclesListScreenState();
}

class _VehiclesListScreenState extends ConsumerState<VehiclesListScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _statusFilter = 'all';
  late final AmbientController _ambient = AmbientController(vsync: this);

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(vehiclesProvider.notifier).loadVehicles(),
    );
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete() async {
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
    return confirmed ?? false;
  }

  Future<void> _delete(VehicleModel vehicle) async {
    try {
      if (vehicle.id == null) return;
      await ref.read(vehiclesProvider.notifier).deleteVehicle(vehicle.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText(AppStrings.successDeleted)),
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

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final contracts = ref.watch(contractsProvider).value ?? const [];

    // The most recent contract per vehicle is the only price the app knows:
    // rates are set per contract, not stored on the vehicle.
    final lastRate = <int, double>{};
    final latest = <int, DateTime>{};
    for (final c in contracts) {
      final seen = latest[c.vehicleId];
      if (seen != null && !c.startDate.isAfter(seen)) continue;
      final rate = impliedDailyRate(c);
      if (rate == null) continue;
      latest[c.vehicleId] = c.startDate;
      lastRate[c.vehicleId] = rate;
    }

    final top = MediaQuery.paddingOf(context).top;
    final expanded = (MediaQuery.sizeOf(context).height * 0.36)
        .clamp(250.0, 340.0)
        .toDouble();
    final collapsed = top + kToolbarHeight;

    final all = vehiclesAsync.value;
    final subtitle = all == null
        ? null
        : context.messages.fleetSummary((all.length).toString(),
            (all.where((v) => v.status == 'available').length).toString());

    // The whole page is dark, from the hero down: a light backdrop under the
    // dark hero made the colours clash, so the page keeps one mood and only the
    // cards are white.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: AdaptiveLayout(
        child: Scaffold(
          backgroundColor: _pageDark,
          body: AmbientListener(
            controller: _ambient,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AmbientImage(
                    controller: _ambient,
                    asset: 'assets/backgrounds/bg_vehicles_body.webp',
                    zoom: 1.14,
                    panFrom: const Alignment(-0.7, 0),
                    panTo: const Alignment(0.7, 0),
                  ),
                ),
                // Keeps the artwork from competing with the cards.
                Positioned.fill(
                  child: ColoredBox(color: _pageDark.withValues(alpha: 0.38)),
                ),
                // Gold sparks drifting behind the list, in the gaps between
                // cards.
                Positioned.fill(
                  child: AmbientGlints(
                    controller: _ambient,
                    tone: GlintTone.onDark,
                    confined: false,
                  ),
                ),
                RefreshIndicator(
                  color: AppColors.gold,
                  edgeOffset: collapsed,
                  onRefresh: () =>
                      ref.read(vehiclesProvider.notifier).loadVehicles(),
                  child: CustomScrollView(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: HeroHeaderDelegate(
                          asset: 'assets/backgrounds/bg_vehicles.webp',
                          eyebrow: AppCopy.yourFleet,
                          title: AppCopy.vehicles,
                          subtitle: subtitle,
                          showTitle: false,
                          expanded: expanded,
                          collapsed: collapsed,
                          topPadding: top,
                          controller: _ambient,
                          // The camera starts on the logo and pans down to the
                          // car as you scroll.
                          startAlignment: const Alignment(0, -0.9),
                          endAlignment: const Alignment(0.25, 0.75),
                          // The photo dissolves into the dark page beneath it,
                          // and the collapsed bar stays dark too.
                          fadeBottom: true,
                          scrimStrength: 0.3,
                          barColor: _pageDark,
                          collapsedForeground: Colors.white,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: context.tr(AppCopy.back),
                            onPressed: () => context.canPop()
                                ? context.pop()
                                : context.go('/dashboard'),
                          ),
                          actions: [
                            ValueListenableBuilder<Set<String>>(
                              valueListenable: licenseFeaturesSignal,
                              builder: (context, features, _) {
                                if (!features
                                    .contains(LicenseFeature.profitability)) {
                                  return const SizedBox.shrink();
                                }
                                return IconButton(
                                  icon: const Icon(Icons.insights_outlined),
                                  tooltip:
                                      context.tr(AppCopy.fleetProfitability),
                                  onPressed: () =>
                                      context.push('/vehicles/profitability'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      ..._contentSlivers(context, vehiclesAsync, lastRate),
                    ],
                  ),
                ),
                // Extra sparks over the hero photo itself.
                Positioned.fill(
                  child: AmbientGlints(
                    controller: _ambient,
                    tone: GlintTone.onDark,
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 0,
                  bottom: 0,
                  child: Center(child: ScrollRail(controller: _ambient)),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/vehicles/add'),
            icon: const Icon(Icons.add),
            label: const AppText(AppCopy.add),
          ),
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    AsyncValue<List<VehicleModel>> vehiclesAsync,
    Map<int, double> lastRate,
  ) {
    return vehiclesAsync.when(
      data: (vehicles) => _dataSlivers(context, vehicles, lastRate),
      loading: () => [
        SliverToBoxAdapter(
          // The shimmer picks its tones from the theme brightness.
          child: Theme(
            data: Theme.of(context).copyWith(brightness: Brightness.dark),
            child: AppShimmer.listLayer(),
          ),
        ),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppText(
                context.trError(error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _dataSlivers(
    BuildContext context,
    List<VehicleModel> vehicles,
    Map<int, double> lastRate,
  ) {
    int count(String status) =>
        vehicles.where((v) => v.status == status).length;

    final filters = [
      (AppCopy.all, 'all', vehicles.length),
      (AppCopy.available61af94, 'available', count('available')),
      (AppCopy.rentede06686, 'rented', count('rented')),
      (AppCopy.maintenance, 'maintenance', count('maintenance')),
    ];

    final q = _searchQuery;
    final filtered = vehicles.where((v) {
      if (_statusFilter != 'all' && v.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return v.brand.toLowerCase().contains(q) ||
          v.model.toLowerCase().contains(q) ||
          v.registrationNumber.toLowerCase().contains(q);
    }).toList();

    final available = count('available');
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: AnimatedTitle(
            color: Colors.white,
            eyebrow: AppCopy.yourFleet,
            title: AppCopy.vehicles,
            subtitle: context.messages.fleetSummary(
                (vehicles.length).toString(), (available).toString()),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.tr(AppCopy.brandModelOrRegistration),
            ),
            onChanged: (value) =>
                setState(() => _searchQuery = value.trim().toLowerCase()),
          ),
        ),
      ),
      // Scrolls sideways when the chips are wider than the screen, instead of
      // overflowing and squeezing the search field.
      SliverToBoxAdapter(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final filter in filters)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: AppText('${context.tr(filter.$1)} (${filter.$3})'),
                    selected: _statusFilter == filter.$2,
                    onSelected: (_) =>
                        setState(() => _statusFilter = filter.$2),
                  ),
                ),
            ],
          ),
        ),
      ),
      if (filtered.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateWidget(
            title: vehicles.isEmpty
                ? AppCopy.noVehiclesSaved
                : AppCopy.noVehiclesFound,
            subtitle: vehicles.isEmpty
                ? AppCopy.addYourFirstVehicleToCreateContracts
                : AppCopy.changeTheSearchOrFilter,
            icon: Icons.directions_car_filled_outlined,
            onDark: true,
            // Top-aligned and compact: under the tall hero there is little
            // room, and a centred message would sit beneath the "Ajouter"
            // button.
            compact: true,
            actionLabel: vehicles.isEmpty ? AppCopy.addAVehicle : null,
            onAction: () => context.push('/vehicles/add'),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final vehicle = filtered[index];
              return Reveal(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Dismissible(
                    key: ValueKey(vehicle.id ?? index),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: AppTone.danger.color,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child:
                          const Icon(Icons.delete_forever, color: Colors.white),
                    ),
                    confirmDismiss: (_) => _confirmDelete(),
                    onDismissed: (_) => _delete(vehicle),
                    child: VehicleCard(
                      vehicle: vehicle,
                      dailyRate: lastRate[vehicle.id],
                      onTap: () {
                        if (vehicle.id != null) {
                          context.push('/vehicles/${vehicle.id}');
                        }
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
    ];
  }
}

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.onTap,
    this.dailyRate,
  });

  final VehicleModel vehicle;
  final VoidCallback onTap;
  final double? dailyRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alerts = maintenanceAlerts(vehicle);
    final urgent = alerts.isEmpty ? null : alerts.first;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Hero(
                tag: 'vehicle_${vehicle.id}',
                child: ParallaxBox(
                  child: VehiclePhoto(
                      vehicle: vehicle, borderRadius: 0, iconSize: 56),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: StatusBadge(text: vehicle.status),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${vehicle.brand} ${vehicle.model}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          PlateBadge(vehicle.registrationNumber),
                        ],
                      ),
                    ),
                    if (dailyRate != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppText(context.money(dailyRate!.round()),
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: AppColors.primary)),
                          AppText(AppCopy.lastRateDay205ab8,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _Fact(Icons.speed_outlined,
                        context.distance(vehicle.currentMileage)),
                    _Fact(fuelTypeIcon(vehicle.fuelType),
                        fuelTypeName(vehicle.fuelType)),
                    _Fact(Icons.settings_outlined,
                        transmissionName(vehicle.transmission)),
                  ],
                ),
                if (urgent != null) ...[
                  const SizedBox(height: 10),
                  StatusChip(
                    label:
                        '${context.tr(urgent.label)} · ${context.tr(urgent.status)}',
                    tone: urgent.tone,
                    icon: urgent.tone.icon,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        AppText(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
