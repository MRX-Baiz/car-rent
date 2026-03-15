import 'dart:convert';
import 'dart:io';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:platform_ocr/platform_ocr.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../data/models/client_model.dart';

/// Default port for the local EasyOCR Python server.
const int kEasyOcrServerPort = 8765;

/// OCR service: dual ML Kit + EasyOCR server.
/// - Android: ML Kit first, EasyOCR server as fallback.
/// - Windows: EasyOCR server first, platform_ocr as fallback when server offline.
/// - iOS/macOS: EasyOCR server first, platform_ocr as fallback when server offline.
class OcrService {
  static String get _serverHost {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return '10.0.2.2'; // Emulator host machine
    return '127.0.0.1';
  }

  String get serverBaseUrl => 'http://$_serverHost:$kEasyOcrServerPort';
  bool _serverActive = false;
  DateTime? _lastServerCheck;
  static const _serverCheckCacheSeconds = 30;

  /// Whether the EasyOCR server is currently reachable (green dot).
  bool get serverActive => _serverActive;

  /// Check if the EasyOCR server is active. Result cached briefly.
  Future<bool> checkServerActive() async {
    if (kIsWeb) return false;
    if (_lastServerCheck != null &&
        DateTime.now().difference(_lastServerCheck!).inSeconds <
            _serverCheckCacheSeconds) {
      return _serverActive;
    }
    try {
      final r = await http
          .get(Uri.parse('$serverBaseUrl/health'))
          .timeout(const Duration(seconds: 2));
      _serverActive = r.statusCode == 200;
      _lastServerCheck = DateTime.now();
      return _serverActive;
    } catch (_) {
      _serverActive = false;
      _lastServerCheck = DateTime.now();
      return false;
    }
  }

  /// Extract text from image via EasyOCR server (POST multipart).
  /// EasyOCR first request can take 60–90s (model load); timeout 2 minutes.
  static const _ocrRequestTimeout = Duration(seconds: 120);

  Future<String> _extractViaEasyOcrServer(File imageFile) async {
    if (!await imageFile.exists()) return '';
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverBaseUrl/ocr'),
      );
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ));
      final streamed = await request.send().timeout(_ocrRequestTimeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(_ocrRequestTimeout);
      if (response.statusCode != 200) return '';
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final text = body?['text'] as String?;
      return text ?? '';
    } catch (e) {
      if (kDebugMode) debugPrint('OcrService EasyOCR server: $e');
      return '';
    }
  }
  /// Extracts text from any supported file (image, PDF, Word).
  /// [filePath] must be a local path. Throws on unsupported type.
  Future<String> extractText(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'bmp':
      case 'gif':
      case 'webp':
        return _extractFromImage(filePath);
      case 'pdf':
        return _extractFromPdf(filePath);
      case 'docx':
      case 'doc':
        return _extractFromWord(filePath);
      default:
        throw Exception('Unsupported file type: $extension');
    }
  }

  Future<String> _extractFromImage(String filePath) async {
    final file = File(filePath);
    return extractTextFromImage(file);
  }

  Future<String> _extractFromPdf(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      try {
        final text = PdfTextExtractor(document).extractText();
        return text ?? '';
      } finally {
        document.dispose();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('OcrService._extractFromPdf: $e');
      return '';
    }
  }

  Future<String> _extractFromWord(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return docxToText(bytes);
    } catch (e) {
      if (kDebugMode) debugPrint('OcrService._extractFromWord: $e');
      return '';
    }
  }

  /// Extracts raw text from [imageFile].
  /// Android: ML Kit first, EasyOCR server as fallback.
  /// Windows/iOS/macOS: EasyOCR server first, platform_ocr as fallback when offline.
  Future<String> extractTextFromImage(File imageFile) async {
    if (!await imageFile.exists()) return '';
    if (kIsWeb) return '';
    try {
      if (Platform.isAndroid) {
        // ML Kit first
        String text = '';
        try {
          final input = InputImage.fromFilePath(imageFile.path);
          final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
          final result = await recognizer.processImage(input);
          await recognizer.close();
          text = result.text;
        } catch (e) {
          if (kDebugMode) debugPrint('OcrService ML Kit: $e');
        }
        // Fallback to EasyOCR server if ML Kit returned nothing
        if (text.trim().isEmpty && await checkServerActive()) {
          text = await _extractViaEasyOcrServer(imageFile);
        }
        return text;
      }
      // Windows, iOS, macOS: EasyOCR server first, then platform_ocr
      if (await checkServerActive()) {
        final text = await _extractViaEasyOcrServer(imageFile);
        if (text.trim().isNotEmpty) return text;
      }
      final ocr = PlatformOcr();
      final text = await ocr.recognizeText(OcrSource.file(imageFile));
      return text != null ? text.toString() : '';
    } catch (e) {
      if (kDebugMode) debugPrint('OcrService.extractTextFromImage: $e');
      return '';
    }
  }

  /// Tries to parse Moroccan CIN format from [ocrText].
  /// Returns a [ClientModel] with filled fields where detected; null if nothing useful.
  Future<ClientModel?> extractCINData(String ocrText) async {
    if (ocrText.trim().isEmpty) return null;
    final lines = ocrText.split(RegExp(r'\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    String? firstName;
    String? lastName;
    String? cin;
    String? address;
    String? birthDate;

    for (final line in lines) {
      // CIN number often matches pattern like 1 letter + 6 digits or similar
      final cinMatch = RegExp(r'\b([A-Za-z]\d{6,10})\b').firstMatch(line);
      if (cinMatch != null && cin == null) cin = cinMatch.group(1);

      // Name: often "Nom / Name" or first two words
      if (line.toLowerCase().contains('nom') || line.toLowerCase().contains('name')) {
        final parts = line.split(RegExp(r'[\s:]+'));
        if (parts.length >= 2) {
          lastName = parts.last;
          if (parts.length >= 3) firstName = parts[parts.length - 2];
        }
      }
      if (line.toLowerCase().contains('adresse') || line.toLowerCase().contains('address')) {
        final idx = line.indexOf(RegExp(r'[:\s]'));
        address = idx >= 0 ? line.substring(idx + 1).trim() : line;
      }
      if (line.contains(RegExp(r'\d{2}[/\-]\d{2}[/\-]\d{4}'))) {
        birthDate = RegExp(r'\d{2}[/\-]\d{2}[/\-]\d{4}').firstMatch(line)?.group(0);
      }
    }

    if (firstName == null && lastName == null && cin == null) return null;

    return ClientModel(
      id: null,
      firstName: firstName ?? '',
      lastName: lastName ?? '',
      cin: cin ?? '',
      licenseNumber: '',
      address: address,
      phone: '',
      email: null,
      cinImagePath: null,
      licenseImagePath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Tries to extract license number, name, and categories from [ocrText].
  Future<Map<String, String>> extractLicenseData(String ocrText) async {
    final result = <String, String>{};
    if (ocrText.trim().isEmpty) return result;

    final lines = ocrText.split(RegExp(r'\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    for (final line in lines) {
      if (line.toLowerCase().contains('permis') || line.toLowerCase().contains('license')) {
        final numMatch = RegExp(r'[\dA-Z]{5,15}').firstMatch(line);
        if (numMatch != null) result['license_number'] = numMatch.group(0)!;
      }
      if (line.toLowerCase().contains('nom') || line.toLowerCase().contains('name')) {
        final parts = line.split(RegExp(r'[\s:]+'));
        if (parts.length >= 2) {
          result['last_name'] = parts.last;
          if (parts.length >= 3) result['first_name'] = parts[parts.length - 2];
        }
      }
      if (line.contains(RegExp(r'[A-B]\d?'))) {
        result['categories'] = RegExp(r'[A-B]\d?').allMatches(line).map((m) => m.group(0)!).join(', ');
      }
    }
    return result;
  }

  /// Parse Moroccan CIN data from extracted text.
  /// Moroccan CIN cards do NOT have "NOM" or "PRENOM" labels; names appear as plain text lines.
  /// Returns map with: firstName, lastName, cin, address, birthDate.
  Map<String, String> parseCINData(String text) {
    final result = <String, String>{
      'firstName': '',
      'lastName': '',
      'cin': '',
      'address': '',
      'birthDate': '',
    };

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Extract CIN number (ex: A123456, BE123456, BJ123456)
    final cinRegex = RegExp(r'\b[A-Z]{1,2}\d{5,6}\b');
    final cinMatch = cinRegex.firstMatch(text);
    if (cinMatch != null) {
      result['cin'] = cinMatch.group(0)!;
    }

    // 2. Extract birth date (ex: 01/01/1990 or 01-01-1990)
    final dateRegex = RegExp(r'\b\d{2}[\/\-]\d{2}[\/\-]\d{4}\b');
    final dateMatch = dateRegex.firstMatch(text);
    if (dateMatch != null) {
      result['birthDate'] = dateMatch.group(0)!;
    }

    // 3. Lines to skip (not names)
    final skipKeywords = [
      'ROYAUME', 'MAROC', 'CARTE', 'NATIONALE', 'IDENTITE',
      'IDENTITY', 'NATIONAL', 'CARD', 'VALABLE', 'VALID',
      'EXPIRE', 'DATE', 'LIEU', 'PLACE', 'BORN', 'NÉ',
      'المملكة', 'المغربية', 'بطاقة', 'التعريف', 'الوطنية',
    ];

    bool isSkippable(String line) {
      if (skipKeywords.any((k) =>
          line.toUpperCase().contains(k.toUpperCase()))) return true;
      if (RegExp(r'\d').hasMatch(line)) return true;
      if (line.length < 3) return true;
      return false;
    }

    bool isArabicName(String line) {
      return RegExp(r'^[\u0600-\u06FF\s]+$').hasMatch(line);
    }

    bool isLatinName(String line) {
      return RegExp(r'^[A-ZÀ-Ÿ\s\-]+$').hasMatch(line) && line.length >= 3;
    }

    // 4. Find name lines — on Moroccan CIN: lastName first, then firstName
    final latinNames = <String>[];
    final arabicNames = <String>[];

    for (final line in lines) {
      if (isSkippable(line)) continue;
      if (isLatinName(line)) {
        latinNames.add(line);
      } else if (isArabicName(line)) {
        arabicNames.add(line);
      }
    }

    if (latinNames.isNotEmpty) {
      result['lastName'] = latinNames[0];
    }
    if (latinNames.length >= 2) {
      result['firstName'] = latinNames[1];
    }

    if (arabicNames.isNotEmpty && (result['lastName'] ?? '').isEmpty) {
      result['lastName'] = arabicNames[0];
    }
    if (arabicNames.length >= 2 && (result['firstName'] ?? '').isEmpty) {
      result['firstName'] = arabicNames[1];
    }

    // 5. Extract address (usually after birth info)
    for (int i = 0; i < lines.length; i++) {
      final upper = lines[i].toUpperCase();
      if (upper.contains('NÉ') || upper.contains('NEE') ||
          upper.contains('BORN') || dateRegex.hasMatch(lines[i])) {
        for (int j = i + 1; j < lines.length && j <= i + 2; j++) {
          if (!isSkippable(lines[j]) && !cinRegex.hasMatch(lines[j])) {
            result['address'] = lines[j];
            break;
          }
        }
        break;
      }
    }

    return result;
  }

  /// Parse driving license data from extracted text.
  /// Returns map with: licenseNumber, firstName, lastName.
  Map<String, String> parseLicenseData(String text) {
    final result = <String, String>{
      'licenseNumber': '',
      'firstName': '',
      'lastName': '',
    };
    if (text.trim().isEmpty) return result;
    final lines = text.split(RegExp(r'\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    for (final line in lines) {
      if (line.toLowerCase().contains('permis') || line.toLowerCase().contains('license') || line.toLowerCase().contains('numero')) {
        final numMatch = RegExp(r'[\dA-Z]{5,15}').firstMatch(line);
        if (numMatch != null && result['licenseNumber']!.isEmpty) result['licenseNumber'] = numMatch.group(0)!;
      }
      if (line.toLowerCase().contains('nom') || line.toLowerCase().contains('name')) {
        final parts = line.split(RegExp(r'[\s:]+'));
        if (parts.length >= 2) {
          result['lastName'] = parts.last;
          if (parts.length >= 3) result['firstName'] = parts[parts.length - 2];
        }
      }
    }
    return result;
  }
}
