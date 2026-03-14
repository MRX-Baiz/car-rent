class VehicleModel {
  final int? id;
  final String brand;
  final String model;
  final String registrationNumber;
  final int year;
  final String status; // 'available', 'rented', 'maintenance'
  final double dailyPrice;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VehicleModel({
    this.id,
    required this.brand,
    required this.model,
    required this.registrationNumber,
    required this.year,
    required this.status,
    required this.dailyPrice,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  VehicleModel copyWith({
    int? id,
    String? brand,
    String? model,
    String? registrationNumber,
    int? year,
    String? status,
    double? dailyPrice,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      year: year ?? this.year,
      status: status ?? this.status,
      dailyPrice: dailyPrice ?? this.dailyPrice,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'registration_number': registrationNumber,
      'year': year,
      'status': status,
      'daily_price': dailyPrice,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    return VehicleModel(
      id: map['id'] as int?,
      brand: map['brand'] as String,
      model: map['model'] as String,
      registrationNumber: map['registration_number'] as String,
      year: map['year'] as int,
      status: map['status'] as String,
      dailyPrice: (map['daily_price'] as num).toDouble(),
      imagePath: map['image_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() {
    return 'VehicleModel(id: $id, brand: $brand, model: $model, registrationNumber: $registrationNumber, year: $year, status: $status, dailyPrice: $dailyPrice)';
  }
}

