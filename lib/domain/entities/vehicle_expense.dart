/// What the agency spent money on for a vehicle. The database stores this as
/// a string; the app works with this type so a typo cannot create an expense
/// that is invisible to every report.
enum VehicleExpenseCategory {
  repair,
  insurance,
  fine,
  other;

  String get storageValue => name;

  static VehicleExpenseCategory? fromStorageValue(String value) {
    for (final category in values) {
      if (category.storageValue == value) return category;
    }
    return null;
  }
}

/// One recorded cost against a vehicle (a repair bill, an insurance premium,
/// a traffic fine...). Revenue is derived from contracts; this is the other
/// half of profitability, which nothing tracked before this.
class VehicleExpense {
  const VehicleExpense({
    required this.id,
    required this.vehicleId,
    required this.category,
    required this.amount,
    required this.date,
    this.notes,
  });

  final int? id;
  final int vehicleId;
  final VehicleExpenseCategory category;
  final double amount;
  final DateTime date;
  final String? notes;
}
