import 'dart:typed_data';

class VehicleModel {
  final int? id;
  final String brand;
  final String model;
  final String registrationNumber;
  final int year;
  final String status; // 'available', 'rented', 'maintenance'
  final String? imagePath;
  final Uint8List? imageBytes;
  final String transmission;
  final String fuelType;
  final String conditionStatus;
  final int currentMileage;
  final int fuelLevel;
  final DateTime? insuranceExpiryDate;
  final DateTime? technicalInspectionExpiryDate;
  final DateTime? vignetteDueDate;
  final DateTime? oilChangeDueDate;
  final int? oilChangeDueMileage;
  final DateTime? distributionDueDate;
  final int? distributionDueMileage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VehicleModel({
    this.id,
    required this.brand,
    required this.model,
    required this.registrationNumber,
    required this.year,
    required this.status,
    this.imagePath,
    this.imageBytes,
    this.transmission = 'manual',
    this.fuelType = 'petrol',
    this.conditionStatus = 'good',
    this.currentMileage = 0,
    this.fuelLevel = 100,
    this.insuranceExpiryDate,
    this.technicalInspectionExpiryDate,
    this.vignetteDueDate,
    this.oilChangeDueDate,
    this.oilChangeDueMileage,
    this.distributionDueDate,
    this.distributionDueMileage,
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
    String? imagePath,
    Uint8List? imageBytes,
    String? transmission,
    String? fuelType,
    String? conditionStatus,
    int? currentMileage,
    int? fuelLevel,
    DateTime? insuranceExpiryDate,
    DateTime? technicalInspectionExpiryDate,
    DateTime? vignetteDueDate,
    DateTime? oilChangeDueDate,
    int? oilChangeDueMileage,
    DateTime? distributionDueDate,
    int? distributionDueMileage,
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
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
      transmission: transmission ?? this.transmission,
      fuelType: fuelType ?? this.fuelType,
      conditionStatus: conditionStatus ?? this.conditionStatus,
      currentMileage: currentMileage ?? this.currentMileage,
      fuelLevel: fuelLevel ?? this.fuelLevel,
      insuranceExpiryDate: insuranceExpiryDate ?? this.insuranceExpiryDate,
      technicalInspectionExpiryDate:
          technicalInspectionExpiryDate ?? this.technicalInspectionExpiryDate,
      vignetteDueDate: vignetteDueDate ?? this.vignetteDueDate,
      oilChangeDueDate: oilChangeDueDate ?? this.oilChangeDueDate,
      oilChangeDueMileage: oilChangeDueMileage ?? this.oilChangeDueMileage,
      distributionDueDate: distributionDueDate ?? this.distributionDueDate,
      distributionDueMileage:
          distributionDueMileage ?? this.distributionDueMileage,
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
      'image_path': imagePath,
      'image_blob': imageBytes,
      'transmission': transmission,
      'fuel_type': fuelType,
      'condition_status': conditionStatus,
      'current_mileage': currentMileage,
      'fuel_level': fuelLevel,
      'insurance_expiry_date': insuranceExpiryDate?.toIso8601String(),
      'technical_inspection_expiry_date':
          technicalInspectionExpiryDate?.toIso8601String(),
      'vignette_due_date': vignetteDueDate?.toIso8601String(),
      'oil_change_due_date': oilChangeDueDate?.toIso8601String(),
      'oil_change_due_mileage': oilChangeDueMileage,
      'distribution_due_date': distributionDueDate?.toIso8601String(),
      'distribution_due_mileage': distributionDueMileage,
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
      imagePath: map['image_path'] as String?,
      imageBytes:
          map['image_blob'] != null ? map['image_blob'] as Uint8List : null,
      transmission: map['transmission'] as String? ?? 'manual',
      fuelType: map['fuel_type'] as String? ?? 'petrol',
      conditionStatus: map['condition_status'] as String? ?? 'good',
      currentMileage: map['current_mileage'] as int? ?? 0,
      fuelLevel: map['fuel_level'] as int? ?? 100,
      insuranceExpiryDate: _date(map['insurance_expiry_date']),
      technicalInspectionExpiryDate:
          _date(map['technical_inspection_expiry_date']),
      vignetteDueDate: _date(map['vignette_due_date']),
      oilChangeDueDate: _date(map['oil_change_due_date']),
      oilChangeDueMileage: map['oil_change_due_mileage'] as int?,
      distributionDueDate: _date(map['distribution_due_date']),
      distributionDueMileage: map['distribution_due_mileage'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  @override
  String toString() {
    return 'VehicleModel(id: $id, brand: $brand, model: $model, registrationNumber: $registrationNumber, year: $year, status: $status)';
  }
}
