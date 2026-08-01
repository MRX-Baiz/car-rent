import 'dart:io';
import 'dart:convert';

/// MODELS
class LicenseData {
  final String name;
  final DateTime expiryDate;
  final String deviceId;

  LicenseData({required this.name, required this.expiryDate, required this.deviceId});

  Map<String, dynamic> toMap() => {
        'name': name,
        'expiry': expiryDate.toIso8601String(),
        'device_id': deviceId,
      };

  String toJson() => json.encode(toMap());
}

class LicensePackage {
  final LicenseData data;
  final String signature;

  LicensePackage({required this.data, required this.signature});

  Map<String, dynamic> toMap() => {'data': data.toMap(), 'signature': signature};

  String encode() => base64.encode(utf8.encode(json.encode(toMap())));
}

void main() async {
  print('\x1B[32m--- CAR RENT MANAGER - SECURE LICENSE GENERATOR ---\x1B[0m');
  print('1. Generate New RSA Key Pair (Private & Public)');
  print('2. Create Signed License Package for a Client');
  stdout.write('\nSelectionner une option / Select option [1-2]: ');
  final choice = stdin.readLineSync();

  if (choice == '1') {
    await _generateKeyPair();
  } else if (choice == '2') {
    await _createSignedLicense();
  } else {
    print('Option invalide.');
  }
}

Future<void> _generateKeyPair() async {
  print('\nGenerating 4096-bit RSA Keys using system OpenSSL...');
  
  try {
    // Generate Private Key
    await Process.run('openssl', ['genrsa', '-out', 'private_key.pem', '4096']);
    // Extract Public Key
    await Process.run('openssl', ['rsa', '-in', 'private_key.pem', '-pubout', '-out', 'public_key.pem']);
    
    print('\x1B[32mSUCCESS!\x1B[0m Keys saved to:');
    print(' - private_key.pem (KEEP THIS SECRET!)');
    print(' - public_key.pem');
    print('\n\x1B[33mACTION REQUIRED:\x1B[0m Copy public_key.pem content into AsymmetricCryptoHelper in the app.');
  } catch (e) {
    print('\x1B[31mError running openssl:\x1B[0m $e');
    print('Ensure openssl is installed and in your PATH.');
  }
}

Future<void> _createSignedLicense() async {
  if (!File('private_key.pem').existsSync()) {
    print('\x1B[31mError:\x1B[0m private_key.pem not found. Generate keys first (Option 1).');
    return;
  }

  stdout.write('Customer Name / Nom du client: ');
  final name = stdin.readLineSync() ?? 'Client';

  stdout.write('Expiry Date / Date d\'expiration (YYYY-MM-DD): ');
  final expiryStr = stdin.readLineSync() ?? '2027-01-01';
  final expiry = DateTime.parse(expiryStr);

  stdout.write('Hardware Device ID / ID de l\'appareil: ');
  final deviceId = (stdin.readLineSync() ?? '').trim();

  if (deviceId.isEmpty) {
    print('\x1B[31mError:\x1B[0m Device ID is mandatory.');
    return;
  }

  final data = LicenseData(name: name, expiryDate: expiry, deviceId: deviceId);
  final dataJson = data.toJson();
  
  print('\nSigning with RSA-PSS SHA-256...');
  
  try {
    // Create a temp file for the JSON data
    final tempIn = File('temp_license_data.json');
    await tempIn.writeAsString(dataJson);
    
    // Sign using OpenSSL
    // Arguments: pkeyutl -sign -inkey private_key.pem -pkeyopt rsa_padding_mode:pss -pkeyopt rsa_pss_saltlen:auto -digest sha256
    final result = await Process.run('openssl', [
      'pkeyutl',
      '-sign',
      '-inkey', 'private_key.pem',
      '-pkeyopt', 'rsa_padding_mode:pss',
      '-pkeyopt', 'rsa_pss_saltlen:auto',
      '-digest', 'sha256',
      '-in', 'temp_license_data.json',
      '-out', 'temp_sig.bin'
    ]);

    if (result.exitCode != 0) {
      throw Exception(result.stderr);
    }

    final signatureBytes = await File('temp_sig.bin').readAsBytes();
    final signatureBase64 = base64.encode(signatureBytes);

    final package = LicensePackage(data: data, signature: signatureBase64);
    final encoded = package.encode();

    print('\x1B[32m\n--- LICENSE GENERATED SUCCESSFULLY ---\x1B[0m');
    print(encoded);
    print('\x1B[32m---------------------------------------\x1B[0m\n');
    
    await File('license_out.txt').writeAsString(encoded);
    print('License saved to license_out.txt');
    
    // Cleanup
    await tempIn.delete();
    await File('temp_sig.bin').delete();
  } catch (e) {
    print('\x1B[31mError during signing:\x1B[0m $e');
  }
}
