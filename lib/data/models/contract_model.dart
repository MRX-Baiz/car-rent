class ContractModel {
  final int? id;
  final String contractNumber; // Auto-generated: "CTR-YYYYMMDD-XXXX"
  final int vehicleId;
  final int primaryDriverId;
  final int? secondaryDriverId;
  final DateTime startDate;
  final DateTime expectedReturnDate;
  final DateTime? actualReturnDate;
  final double totalPrice;
  final double amountPaid;
  final String status; // 'active', 'completed', 'late'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContractModel({
    this.id,
    required this.contractNumber,
    required this.vehicleId,
    required this.primaryDriverId,
    this.secondaryDriverId,
    required this.startDate,
    required this.expectedReturnDate,
    this.actualReturnDate,
    required this.totalPrice,
    required this.amountPaid,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remainingAmount => totalPrice - amountPaid;

  int get rentalDays => expectedReturnDate.difference(startDate).inDays;

  bool get isLate => status == 'active' && DateTime.now().isAfter(expectedReturnDate);

  ContractModel copyWith({
    int? id,
    String? contractNumber,
    int? vehicleId,
    int? primaryDriverId,
    int? secondaryDriverId,
    DateTime? startDate,
    DateTime? expectedReturnDate,
    DateTime? actualReturnDate,
    double? totalPrice,
    double? amountPaid,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContractModel(
      id: id ?? this.id,
      contractNumber: contractNumber ?? this.contractNumber,
      vehicleId: vehicleId ?? this.vehicleId,
      primaryDriverId: primaryDriverId ?? this.primaryDriverId,
      secondaryDriverId: secondaryDriverId ?? this.secondaryDriverId,
      startDate: startDate ?? this.startDate,
      expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
      actualReturnDate: actualReturnDate ?? this.actualReturnDate,
      totalPrice: totalPrice ?? this.totalPrice,
      amountPaid: amountPaid ?? this.amountPaid,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contract_number': contractNumber,
      'vehicle_id': vehicleId,
      'primary_driver_id': primaryDriverId,
      'secondary_driver_id': secondaryDriverId,
      'start_date': startDate.toIso8601String(),
      'expected_return_date': expectedReturnDate.toIso8601String(),
      'actual_return_date': actualReturnDate?.toIso8601String(),
      'total_price': totalPrice,
      'amount_paid': amountPaid,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ContractModel.fromMap(Map<String, dynamic> map) {
    return ContractModel(
      id: map['id'] as int?,
      contractNumber: map['contract_number'] as String,
      vehicleId: map['vehicle_id'] as int,
      primaryDriverId: map['primary_driver_id'] as int,
      secondaryDriverId: map['secondary_driver_id'] as int?,
      startDate: DateTime.parse(map['start_date'] as String),
      expectedReturnDate: DateTime.parse(map['expected_return_date'] as String),
      actualReturnDate: map['actual_return_date'] != null
          ? DateTime.parse(map['actual_return_date'] as String)
          : null,
      totalPrice: (map['total_price'] as num).toDouble(),
      amountPaid: (map['amount_paid'] as num).toDouble(),
      status: map['status'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

