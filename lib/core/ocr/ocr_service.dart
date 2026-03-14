import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/models/client_model.dart';

/// OCR service for extracting text from CIN and license images.
/// On Android uses Google ML Kit; on Windows/other platforms uses file picker
/// and placeholder parsing until ML Kit or another engine is available.
class OcrService {
  /// Extracts raw text from [imageFile].
  /// On Android: uses ML Kit text recognition.
  /// On other platforms: returns empty string (caller can use file picker and manual entry).
  Future<String> extractTextFromImage(File imageFile) async {
    if (!await imageFile.exists()) return '';
    if (kIsWeb) return '';
    // Android: use google_mlkit_text_recognition when available.
    // if (Platform.isAndroid) {
    //   final input = InputImage.fromFilePath(imageFile.path);
    //   final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    //   final result = await recognizer.processImage(input);
    //   await recognizer.close();
    //   return result.text;
    // }
    return '';
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
