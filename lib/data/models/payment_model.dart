class PaymentModel {
  final int? id;
  final int contractId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod; // e.g. 'cash', 'card', 'bank_transfer'
  final String? notes;
  final DateTime createdAt;

  const PaymentModel({
    this.id,
    required this.contractId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
  });

  PaymentModel copyWith({
    int? id,
    int? contractId,
    double? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      contractId: contractId ?? this.contractId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contract_id': contractId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as int?,
      contractId: map['contract_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(map['payment_date'] as String),
      paymentMethod: map['payment_method'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

