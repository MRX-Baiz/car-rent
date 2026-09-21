class ContractDocument {
  const ContractDocument(this.data);

  final Map<String, Object?> data;

  int get contractId => data['contract_id'] as int;
  String get originalPath => data['original_path'] as String;
  String get originalHash => data['original_hash'] as String;
  String? get signedPath => data['signed_path'] as String?;
  String? get signedHash => data['signed_hash'] as String?;
  String get method => data['method'] as String;
  bool get isSigned => signedPath != null;
  String get signerName => data['signer_name'] as String;
  String get signerCin => data['signer_cin'] as String;
  DateTime? get recordedAt => data['recorded_at'] == null
      ? null
      : DateTime.parse(data['recorded_at'] as String);
}
