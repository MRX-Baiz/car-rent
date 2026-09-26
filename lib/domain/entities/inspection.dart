import 'dart:typed_data';

enum InspectionKind {
  departure('departure'),
  returning('return');

  const InspectionKind(this.storageValue);

  final String storageValue;

  static InspectionKind fromStorageValue(String value) {
    return values.firstWhere((kind) => kind.storageValue == value);
  }
}

class InspectionReading {
  const InspectionReading({
    required this.contractId,
    required this.kind,
    required this.mileage,
    required this.fuelLevel,
    required this.conditionStatus,
    required this.createdAt,
    this.damageNotes,
    this.extraCharges = 0,
    this.signaturePath,
  });

  final int contractId;
  final InspectionKind kind;
  final int mileage;
  final int fuelLevel;
  final String conditionStatus;
  final String? damageNotes;
  final double extraCharges;
  final String? signaturePath;
  final DateTime createdAt;
}

/// Vehicle fields required while inspecting a rental; it does not expose a
/// persistence model to the screen.
class InspectionVehicle {
  const InspectionVehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.registrationNumber,
    required this.currentMileage,
    required this.fuelLevel,
    required this.conditionStatus,
    this.imagePath,
    this.imageBytes,
  });

  final int id;
  final String brand;
  final String model;
  final String registrationNumber;
  final int currentMileage;
  final int fuelLevel;
  final String conditionStatus;
  final String? imagePath;
  final Uint8List? imageBytes;
}

class InspectionContext {
  const InspectionContext({
    required this.contractNumber,
    required this.vehicle,
    this.departureReading,
  });

  final String contractNumber;
  final InspectionVehicle vehicle;
  final InspectionReading? departureReading;
}

class InspectionDraft {
  const InspectionDraft({
    required this.contractId,
    required this.kind,
    required this.mileage,
    required this.fuelLevel,
    required this.conditionStatus,
    required this.photoSourcePaths,
    required this.createdAt,
    this.damageNotes,
    this.extraCharges = 0,
    this.signature,
  });

  final int contractId;
  final InspectionKind kind;
  final int mileage;
  final int fuelLevel;
  final String conditionStatus;
  final String? damageNotes;
  final double extraCharges;
  final Map<String, String> photoSourcePaths;
  final Uint8List? signature;
  final DateTime createdAt;
}
