import 'dart:convert';

class LicenseData {
  final String name;
  final DateTime expiryDate;
  final String deviceId;

  /// Which gated features this licence includes, e.g. `LicenseFeature.
  /// customerHistory`. Empty for every licence issued before this field
  /// existed, and for one deliberately issued with no extra features.
  final Set<String> features;

  LicenseData({
    required this.name,
    required this.expiryDate,
    required this.deviceId,
    this.features = const {},
  });

  // `verifyLicense` checks the signature by re-deriving this JSON from the
  // decoded object, not by keeping the original signed bytes around — so
  // this must serialize an old, feature-less licence to the exact same bytes
  // it was signed with. Omitting the key entirely when empty (rather than
  // emitting `"features":[]`) is what makes that hold; do not "simplify" this
  // to an unconditional key or every licence issued before this field
  // existed stops verifying. Sorted, so the signed bytes never depend on
  // insertion order.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'expiry': expiryDate.toIso8601String(),
      'device_id': deviceId,
      if (features.isNotEmpty) 'features': (features.toList()..sort()),
    };
  }

  factory LicenseData.fromMap(Map<String, dynamic> map) {
    return LicenseData(
      name: map['name'] as String,
      expiryDate: DateTime.parse(map['expiry'] as String),
      deviceId: map['device_id'] as String,
      features:
          (map['features'] as List<dynamic>?)?.cast<String>().toSet() ??
              const {},
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
