import 'vehicle_expense.dart';

/// The minimal shape a contract needs to expose for profitability math,
/// mapped from [ContractModel] at the data boundary so the use case that
/// consumes it stays free of persistence details.
class ProfitabilityContract {
  const ProfitabilityContract({
    required this.vehicleId,
    required this.startDate,
    required this.actualReturnDate,
    required this.isActive,
    required this.amountPaid,
  });

  final int vehicleId;
  final DateTime startDate;

  /// Set once the rental is over. Null while [isActive].
  final DateTime? actualReturnDate;
  final bool isActive;

  /// Cash actually collected — not the full billed price, so an unpaid
  /// balance on a late contract never inflates a vehicle's revenue.
  final double amountPaid;
}

/// Revenue, rental days, utilization, expenses and net profit for one
/// vehicle — the numbers that say whether it's worth buying again or selling.
class VehicleProfitability {
  const VehicleProfitability({
    required this.vehicleId,
    required this.revenue,
    required this.rentalDays,
    required this.daysTracked,
    required this.utilizationPercent,
    required this.expensesByCategory,
    required this.totalExpenses,
    required this.netProfit,
  });

  final int vehicleId;

  /// Cash collected across every contract for this vehicle.
  final double revenue;

  /// Total days the vehicle was out on a contract (in-progress rentals count
  /// up to "now").
  final int rentalDays;

  /// Days since the vehicle was added to the app — the denominator behind
  /// [utilizationPercent]. There is no purchase-date field yet, so this is an
  /// approximation for a car added well after it was actually bought.
  final int daysTracked;

  /// `rentalDays / daysTracked * 100`, clamped to 0–100. Null when
  /// [daysTracked] is 0 (a vehicle added today), to avoid a false 0% or a
  /// division by zero.
  final double? utilizationPercent;

  final Map<VehicleExpenseCategory, double> expensesByCategory;
  final double totalExpenses;

  /// [revenue] minus [totalExpenses]. Negative means the vehicle is a net
  /// loss so far.
  final double netProfit;
}
