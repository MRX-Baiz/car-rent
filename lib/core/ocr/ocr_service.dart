import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:platform_ocr/platform_ocr.dart';

import '../../data/models/client_model.dart';

/// OCR service for extracting text from CIN and license images.
/// - Android: Google ML Kit.
/// - Windows / iOS / macOS: platform_ocr (native OS API).
class OcrService {
  /// Extracts raw text from [imageFile].
  /// Uses ML Kit on Android; platform_ocr (native) on Windows, iOS, macOS.
  Future<String> extractTextFromImage(File imageFile) async {
    if (!await imageFile.exists()) return '';
    if (kIsWeb) return '';
    try {
      if (Platform.isAndroid) {
        final input = InputImage.fromFilePath(imageFile.path);
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final result = await recognizer.processImage(input);
        await recognizer.close();
        return result.text;
      }
      // Windows, iOS, macOS: native OS OCR
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
}
