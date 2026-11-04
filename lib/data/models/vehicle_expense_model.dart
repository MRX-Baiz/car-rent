class VehicleExpenseModel {
  const VehicleExpenseModel({
    this.id,
    required this.vehicleId,
    required this.category,
    required this.amount,
    required this.expenseDate,
    this.notes,
    required this.createdAt,
  });

  final int? id;
  final int vehicleId;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String? notes;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'category': category,
        'amount': amount,
        'expense_date': expenseDate.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory VehicleExpenseModel.fromMap(Map<String, dynamic> map) =>
      VehicleExpenseModel(
        id: map['id'] as int?,
        vehicleId: map['vehicle_id'] as int,
        category: map['category'] as String,
        amount: (map['amount'] as num).toDouble(),
        expenseDate: DateTime.parse(map['expense_date'] as String),
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
