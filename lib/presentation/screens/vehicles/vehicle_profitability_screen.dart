import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/license/license_features.dart';
import '../../../core/license/license_manager.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../domain/entities/vehicle_profitability.dart';
import '../../providers/vehicle_profitability_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/dashboard/stat_card.dart';
import '../../widgets/layout/app_page.dart';

/// Ranks every vehicle by net profit, so the operator can see at a glance
/// which cars are worth buying again and which are losing money.
class VehicleProfitabilityScreen extends ConsumerWidget {
  const VehicleProfitabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The nav icon that links here is already hidden without the licence
    // feature, but that's only a shortcut — someone reaching this route
    // directly (a saved link, typed URL) must not see real business data
    // either, so the screen itself checks too.
    return ValueListenableBuilder<Set<String>>(
      valueListenable: licenseFeaturesSignal,
      builder: (context, features, _) {
        if (!features.contains(LicenseFeature.profitability)) {
          return const AppPage(
            title: AppCopy.fleetProfitability,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyStateWidget(
                  title: AppCopy.featureNotIncludedInLicence,
                  icon: Icons.lock_outline,
                ),
              ),
            ],
          );
        }
        return const _FleetProfitability();
      },
    );
  }
}

class _FleetProfitability extends ConsumerWidget {
  const _FleetProfitability();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final vehiclesById = {
      for (final vehicle in vehicles)
        if (vehicle.id != null) vehicle.id!: vehicle,
    };
    final profitability = ref.watch(fleetProfitabilityProvider);

    return AppPage(
      title: AppCopy.fleetProfitability,
      children: profitability.when(
        loading: () => const [
          Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        error: (error, _) => [
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: AppText(context.trError(error))),
          ),
        ],
        data: (results) {
          if (results.isEmpty) {
            return const [
              Padding(
                padding: EdgeInsets.only(top: 20),
                child: EmptyStateWidget(
                  title: AppCopy.noVehiclesToRank,
                  icon: Icons.directions_car_outlined,
                ),
              ),
            ];
          }
          final totalRevenue =
              results.fold(0.0, (sum, item) => sum + item.revenue);
          final totalExpenses =
              results.fold(0.0, (sum, item) => sum + item.totalExpenses);
          final totalNetProfit =
              results.fold(0.0, (sum, item) => sum + item.netProfit);
          // StatCard fills whatever height it's given (mainAxisSize.max), so
          // it needs a bounded one here — the same 124dp the dashboard's own
          // stat grid uses — rather than the unbounded height a bare Row
          // hands its children.
          return [
            SizedBox(
              height: 124,
              child: Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: context.tr(AppCopy.fleetTotalRevenue),
                      value: context.money(totalRevenue),
                      icon: Icons.payments_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: context.tr(AppCopy.fleetTotalExpenses),
                      value: context.money(totalExpenses),
                      icon: Icons.receipt_long_outlined,
                      color: AppTone.warning.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 124,
              child: StatCard(
                title: context.tr(AppCopy.fleetTotalNetProfit),
                value: context.money(totalNetProfit),
                icon: totalNetProfit >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: totalNetProfit >= 0
                    ? AppTone.success.color
                    : AppTone.danger.color,
              ),
            ),
            const SizedBox(height: 20),
            for (final result in results)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VehicleProfitabilityRow(
                  profitability: result,
                  vehicle: vehiclesById[result.vehicleId],
                  onTap: () => context.push('/vehicles/${result.vehicleId}'),
                ),
              ),
          ];
        },
      ),
    );
  }
}

class _VehicleProfitabilityRow extends StatelessWidget {
  const _VehicleProfitabilityRow({
    required this.profitability,
    required this.vehicle,
    required this.onTap,
  });

  final VehicleProfitability profitability;
  final VehicleModel? vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone =
        profitability.netProfit >= 0 ? AppTone.success : AppTone.danger;
    final car = vehicle;
    final label = car == null
        ? context.messages.vehicleNumber(profitability.vehicleId.toString())
        : '${car.brand} ${car.model}';
    final plate = car?.registrationNumber;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall),
                if (plate != null)
                  AppText(plate,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                AppText(
                  '${context.tr(AppCopy.revenue)} ${context.money(profitability.revenue)} · '
                  '${context.tr(AppCopy.totalExpenses)} ${context.money(profitability.totalExpenses)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(
                label: context.money(profitability.netProfit),
                tone: tone,
                icon: profitability.netProfit >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                dense: true,
              ),
              if (profitability.utilizationPercent != null) ...[
                const SizedBox(height: 6),
                AppText(
                  '${profitability.utilizationPercent!.round()} %',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
