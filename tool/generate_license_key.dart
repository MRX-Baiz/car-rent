import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  const secretKey = 'YOUR_SECRET_KEY_HERE_32CHARS';
  const companyId = 'DEMO';
  final expiry = DateTime(2026, 12, 31);
  final yyyy = expiry.year.toString().padLeft(4, '0');
  final mm = expiry.month.toString().padLeft(2, '0');
  final dd = expiry.day.toString().padLeft(2, '0');
  final data = '$companyId-$yyyy-$mm-$dd';
  final key = utf8.encode(secretKey);
  final bytes = utf8.encode(data);
  final hmacSha256 = Hmac(sha256, key);
  final digest = hmacSha256.convert(bytes);
  final signature =
      digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final licenseKey = '$companyId-$yyyy-$mm-$dd-$signature';
  print(licenseKey);
}
