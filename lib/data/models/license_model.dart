import 'dart:convert';

class LicenseData {
  final String name;
  final DateTime expiryDate;
  final String deviceId;

  LicenseData({
    required this.name,
    required this.expiryDate,
    required this.deviceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'expiry': expiryDate.toIso8601String(),
      'device_id': deviceId,
    };
  }

  factory LicenseData.fromMap(Map<String, dynamic> map) {
    return LicenseData(
      name: map['name'] as String,
      expiryDate: DateTime.parse(map['expiry'] as String),
      deviceId: map['device_id'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory LicenseData.fromJson(String source) =>
      LicenseData.fromMap(json.decode(source) as Map<String, dynamic>);
}

class LicensePackage {
  final LicenseData data;
  final String signature;

  LicensePackage({
    required this.data,
    required this.signature,
  });

  Map<String, dynamic> toMap() {
    return {
      'data': data.toMap(),
      'signature': signature,
    };
  }

  factory LicensePackage.fromMap(Map<String, dynamic> map) {
    return LicensePackage(
      data: LicenseData.fromMap(map['data'] as Map<String, dynamic>),
      signature: map['signature'] as String,
    );
  }

  String encode() => base64.encode(utf8.encode(json.encode(toMap())));

  factory LicensePackage.decode(String encoded) {
    final decoded = utf8.decode(base64.decode(encoded));
    return LicensePackage.fromMap(json.decode(decoded) as Map<String, dynamic>);
  }
}
