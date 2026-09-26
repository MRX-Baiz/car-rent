class InspectionModel {
  const InspectionModel(
      {this.id,
      required this.contractId,
      required this.type,
      required this.mileage,
      required this.fuelLevel,
      required this.conditionStatus,
      this.damageNotes,
      this.extraCharges = 0,
      this.signaturePath,
      required this.createdAt});
  final int? id;
  final int contractId, mileage, fuelLevel;
  final String type, conditionStatus;
  final String? damageNotes, signaturePath;
  final double extraCharges;
  final DateTime createdAt;
  Map<String, dynamic> toMap() => {
        'id': id,
        'contract_id': contractId,
        'type': type,
        'mileage': mileage,
        'fuel_level': fuelLevel,
        'condition_status': conditionStatus,
        'damage_notes': damageNotes,
        'extra_charges': extraCharges,
        'signature_path': signaturePath,
        'created_at': createdAt.toIso8601String()
      };
  factory InspectionModel.fromMap(Map<String, dynamic> map) => InspectionModel(
      id: map['id'] as int?,
      contractId: map['contract_id'] as int,
      type: map['type'] as String,
      mileage: map['mileage'] as int,
      fuelLevel: map['fuel_level'] as int,
      conditionStatus: map['condition_status'] as String,
      damageNotes: map['damage_notes'] as String?,
      extraCharges: (map['extra_charges'] as num).toDouble(),
      signaturePath: map['signature_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String));
}

class InspectionPhotoDraft {
  const InspectionPhotoDraft(this.kind, this.path);
  final String kind, path;
}
