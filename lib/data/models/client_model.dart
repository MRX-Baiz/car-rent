class ClientModel {
  final int? id;
  final String firstName;
  final String lastName;
  final String cin;
  final String licenseNumber;
  final String? address;
  final String phone;
  final String? email;
  final String? cinImagePath;
  final String? licenseImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClientModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.cin,
    required this.licenseNumber,
    this.address,
    required this.phone,
    this.email,
    this.cinImagePath,
    this.licenseImagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $lastName';

  ClientModel copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? cin,
    String? licenseNumber,
    String? address,
    String? phone,
    String? email,
    String? cinImagePath,
    String? licenseImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      cin: cin ?? this.cin,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      cinImagePath: cinImagePath ?? this.cinImagePath,
      licenseImagePath: licenseImagePath ?? this.licenseImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'cin': cin,
      'license_number': licenseNumber,
      'address': address,
      'phone': phone,
      'email': email,
      'cin_image_path': cinImagePath,
      'license_image_path': licenseImagePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id'] as int?,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      cin: map['cin'] as String,
      licenseNumber: map['license_number'] as String,
      address: map['address'] as String?,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      cinImagePath: map['cin_image_path'] as String?,
      licenseImagePath: map['license_image_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

