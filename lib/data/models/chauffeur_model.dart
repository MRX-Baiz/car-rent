class ChauffeurModel {
  const ChauffeurModel(
      {this.id,
      required this.firstName,
      required this.lastName,
      required this.cin,
      required this.licenseNumber,
      required this.phone,
      this.licenseExpiryDate,
      required this.hourlyRate,
      this.status = 'available',
      this.notes,
      required this.createdAt,
      required this.updatedAt});
  final int? id;
  final String firstName, lastName, cin, licenseNumber, phone, status;
  final DateTime? licenseExpiryDate;
  final double hourlyRate;
  final String? notes;
  final DateTime createdAt, updatedAt;
  String get fullName => '$firstName $lastName';
  ChauffeurModel copyWith(
          {int? id,
          String? firstName,
          String? lastName,
          String? cin,
          String? licenseNumber,
          String? phone,
          DateTime? licenseExpiryDate,
          double? hourlyRate,
          String? status,
          String? notes,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ChauffeurModel(
          id: id ?? this.id,
          firstName: firstName ?? this.firstName,
          lastName: lastName ?? this.lastName,
          cin: cin ?? this.cin,
          licenseNumber: licenseNumber ?? this.licenseNumber,
          phone: phone ?? this.phone,
          licenseExpiryDate: licenseExpiryDate ?? this.licenseExpiryDate,
          hourlyRate: hourlyRate ?? this.hourlyRate,
          status: status ?? this.status,
          notes: notes ?? this.notes,
          createdAt: createdAt ?? this.createdAt,
          updatedAt: updatedAt ?? this.updatedAt);
  Map<String, dynamic> toMap() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'cin': cin,
        'license_number': licenseNumber,
        'phone': phone,
        'license_expiry_date': licenseExpiryDate?.toIso8601String(),
        'hourly_rate': hourlyRate,
        'status': status,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String()
      };
  factory ChauffeurModel.fromMap(Map<String, dynamic> map) => ChauffeurModel(
      id: map['id'] as int?,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      cin: map['cin'] as String,
      licenseNumber: map['license_number'] as String,
      phone: map['phone'] as String,
      licenseExpiryDate: map['license_expiry_date'] is String
          ? DateTime.tryParse(map['license_expiry_date'] as String)
          : null,
      hourlyRate: (map['hourly_rate'] as num).toDouble(),
      status: map['status'] as String? ?? 'available',
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String));
}
