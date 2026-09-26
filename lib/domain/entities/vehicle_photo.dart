/// A supported photo slot on a vehicle record.
///
/// The database stores these values as strings, while the app works with this
/// type so a typo cannot create a photo that is never shown to the operator.
enum VehiclePhotoKind {
  front,
  back,
  left,
  right,
  damage;

  String get storageValue => name;

  static VehiclePhotoKind? fromStorageValue(String value) {
    for (final kind in values) {
      if (kind.storageValue == value) return kind;
    }
    return null;
  }
}
