import '../entities/vehicle_expense.dart';
import '../entities/vehicle_profitability.dart';

/// Turns a vehicle's contracts and expenses into the numbers that say
/// whether it's worth keeping: revenue, rental days, utilization, expenses
/// by category, and net profit.
///
/// Deliberately pure — no repository dependency, no database access. The
/// provider layer joins the already-loaded contracts/vehicles providers and
/// hands this plain data, the same shape `BuildTodayOperations` takes plain
/// operations entities rather than reading storage itself. That keeps this
/// testable with plain objects and avoids a second database read of
/// contracts that are already sitting in memory.
class ComputeVehicleProfitability {
  const ComputeVehicleProfitability();

  VehicleProfitability call({
    required int vehicleId,
    required Iterable<ProfitabilityContract> contracts,
    required Iterable<VehicleExpense> expenses,
    required DateTime addedAt,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final ownContracts =
        contracts.where((contract) => contract.vehicleId == vehicleId);
    final ownExpenses =
        expenses.where((expense) => expense.vehicleId == vehicleId);

    var revenue = 0.0;
    var rentalDays = 0;
    for (final contract in ownContracts) {
      revenue += contract.amountPaid;
      final end = contract.actualReturnDate ??
          (contract.isActive ? today : null);
      if (end == null) continue;
      final days = end.difference(contract.startDate).inDays;
      if (days > 0) rentalDays += days;
    }

    final expensesByCategory = <VehicleExpenseCategory, double>{};
    for (final expense in ownExpenses) {
      expensesByCategory.update(
        expense.category,
        (total) => total + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    final totalExpenses =
        expensesByCategory.values.fold(0.0, (sum, value) => sum + value);

    final daysTracked = today.difference(addedAt).inDays;
    final trackedDays = daysTracked < 0 ? 0 : daysTracked;
    final utilizationPercent = trackedDays <= 0
        ? null
        : (rentalDays / trackedDays * 100).clamp(0, 100).toDouble();

    return VehicleProfitability(
      vehicleId: vehicleId,
      revenue: revenue,
      rentalDays: rentalDays,
      daysTracked: trackedDays,
      utilizationPercent: utilizationPercent,
      expensesByCategory: expensesByCategory,
      totalExpenses: totalExpenses,
      netProfit: revenue - totalExpenses,
    );
  }
}
