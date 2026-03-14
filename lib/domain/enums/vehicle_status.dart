enum VehicleStatus {
  available,
  rented,
  maintenance,
}

extension VehicleStatusX on VehicleStatus {
  String get dbValue {
    switch (this) {
      case VehicleStatus.available:
        return 'available';
      case VehicleStatus.rented:
        return 'rented';
      case VehicleStatus.maintenance:
        return 'maintenance';
    }
  }

  static VehicleStatus fromDb(String value) {
    switch (value) {
      case 'available':
        return VehicleStatus.available;
      case 'rented':
        return VehicleStatus.rented;
      case 'maintenance':
        return VehicleStatus.maintenance;
      default:
        return VehicleStatus.available;
    }
  }
}

