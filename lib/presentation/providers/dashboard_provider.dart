import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/contract_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/vehicle_repository.dart';

class DashboardStats {
  final int availableVehicles;
  final int rentedVehicles;
  final int activeContracts;
  final int lateContracts;
  final double totalRevenue;
  final List<MapEntry<DateTime, double>> weeklyRevenue;

  const DashboardStats({
    required this.availableVehicles,
    required this.rentedVehicles,
    required this.activeContracts,
    required this.lateContracts,
    required this.totalRevenue,
    required this.weeklyRevenue,
  });
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardStats>(
  DashboardNotifier.new,
);

class DashboardNotifier extends AsyncNotifier<DashboardStats> {
  final VehicleRepository _vehicleRepository = VehicleRepository.instance;
  final ContractRepository _contractRepository = ContractRepository.instance;
  final PaymentRepository _paymentRepository = PaymentRepository.instance;

  @override
  FutureOr<DashboardStats> build() async {
    return _loadStats();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadStats);
  }

  Future<DashboardStats> _loadStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));

    final available = await _vehicleRepository.getAvailableVehiclesCount();
    final rented = await _vehicleRepository.getRentedVehiclesCount();
    final activeContracts =
        await _contractRepository.getActiveContractsCount();
    final lateContracts =
        (await _contractRepository.getLateContracts()).length;
    final totalRevenue =
        await _paymentRepository.getTotalRevenueForMonth(now);

    // Fetch daily revenue for the last 7 days
    final dailyRevenueMap = await _paymentRepository.getDailyRevenue(
      sevenDaysAgo,
      today.add(const Duration(days: 1)),
    );

    // Ensure we have an entry for every day in the range, even if 0
    final List<MapEntry<DateTime, double>> weeklyRevenue = [];
    for (int i = 0; i < 7; i++) {
      final date = sevenDaysAgo.add(Duration(days: i));
      final amount = dailyRevenueMap[date] ?? 0.0;
      weeklyRevenue.add(MapEntry(date, amount));
    }

    return DashboardStats(
      availableVehicles: available,
      rentedVehicles: rented,
      activeContracts: activeContracts,
      lateContracts: lateContracts,
      totalRevenue: totalRevenue,
      weeklyRevenue: weeklyRevenue,
    );
  }
}


