import 'dart:io';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ocr_native/flutter_ocr_native.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' hide TextLine;

import '../../data/models/client_model.dart';

/// OCR service backed by each platform's built-in text recognition engine:
/// ML Kit on Android, Apple Vision on iOS/macOS, WinRT OCR on Windows.
///
/// Runs fully on-device with no server, no network and no model downloads,
/// so the app ships as a single self-contained binary on every platform.
class OcrService {
  /// Aadhaar masking is deliberately disabled: it rewrites digit groups and
  /// would corrupt Moroccan CIN / permit numbers.
  final OcrReader _reader = OcrReader(
    validateDocument: false,
    maskAadhaar: false,
  );

  /// Native OCR is unavailable only on web, where there is no platform engine.
  bool get isOcrAvailable => !kIsWeb;

  Future<String> _extractViaNativeOcr(File imageFile) async {
    if (!await imageFile.exists()) return '';
    try {
      final result = await _reader.readFromFile(imageFile);
      return result.text;
    } catch (e) {
      if (kDebugMode) debugPrint('OcrService native OCR: $e');
      return '';
    }
  }

  /// Recognized text lines with their positions on the image, ordered
  /// top-to-bottom. Bounding boxes enable field localization on the fixed
  /// CIN / permis layouts, which flat text alone cannot support.
  Future<List<TextLine>> extractLines(File imageFile) async {
    if (kIsWeb || !await imageFile.exists()) return const [];
    try {
      final result = await _reader.readFromFile(imageFile);
      final lines = result.blocks.expand((b) => b.lines).toList()
        ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
      return lines;
    } catch (e) {
      if (kDebugMode) debugPrint('OcrService.extractLines: $e');
      return const [];
    }
  }

  Future<void> dispose() => _reader.dispose();

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
        // ignore: dead_null_aware_expression - syncfusion API may return null at runtime
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

  /// Extracts raw text from [imageFile] using the platform's native OCR engine.
  Future<String> extractTextFromImage(File imageFile) async {
    if (kIsWeb) return '';
    return _extractViaNativeOcr(imageFile);
  }

  /// Tries to parse Moroccan CIN format from [ocrText].
  /// Returns a [ClientModel] with filled fields where detected; null if nothing useful.
  Future<ClientModel?> extractCINData(String ocrText) async {
    if (ocrText.trim().isEmpty) return null;
    final lines = ocrText
        .split(RegExp(r'\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    String? firstName;
    String? lastName;
    String? cin;
    String? address;

    for (final line in lines) {
      // CIN number often matches pattern like 1 letter + 6 digits or similar
      final cinMatch = RegExp(r'\b([A-Za-z]\d{6,10})\b').firstMatch(line);
      if (cinMatch != null && cin == null) cin = cinMatch.group(1);

      // Name: often "Nom / Name" or first two words
      if (line.toLowerCase().contains('nom') ||
          line.toLowerCase().contains('name')) {
        final parts = line.split(RegExp(r'[\s:]+'));
        if (parts.length >= 2) {
          lastName = parts.last;
          if (parts.length >= 3) firstName = parts[parts.length - 2];
        }
      }
      if (line.toLowerCase().contains('adresse') ||
          line.toLowerCase().contains('address')) {
        final idx = line.indexOf(RegExp(r'[:\s]'));
        address = idx >= 0 ? line.substring(idx + 1).trim() : line;
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

    final lines = ocrText
        .split(RegExp(r'\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    for (final line in lines) {
      if (line.toLowerCase().contains('permis') ||
          line.toLowerCase().contains('license')) {
        final numMatch = RegExp(r'[\dA-Z]{5,15}').firstMatch(line);
        if (numMatch != null) result['license_number'] = numMatch.group(0)!;
      }
      if (line.toLowerCase().contains('nom') ||
          line.toLowerCase().contains('name')) {
        final parts = line.split(RegExp(r'[\s:]+'));
        if (parts.length >= 2) {
          result['last_name'] = parts.last;
          if (parts.length >= 3) result['first_name'] = parts[parts.length - 2];
        }
      }
      if (line.contains(RegExp(r'[A-B]\d?'))) {
        result['categories'] = RegExp(r'[A-B]\d?')
            .allMatches(line)
            .map((m) => m.group(0)!)
            .join(', ');
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
      'expiryDate': '',
    };

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Extract CIN number (commonly 1–2 letters + 5–10 digits, case-insensitive).
    // Examples: D123356, T482916, BE123456.
    final cinRegex = RegExp(r'\b[A-Z]{1,2}\d{5,10}\b', caseSensitive: false);
    final cinMatch = cinRegex.firstMatch(text);
    if (cinMatch != null) {
      final value = (cinMatch.group(0) ?? '').trim();
      // Guard against OCR returning labels like "CIN".
      if (value.isNotEmpty && value.toUpperCase() != 'CIN') {
        result['cin'] = value.toUpperCase();
      }
    }

    // 2. Extract dates (ex: 01/01/1990 or 01-01-1990 or 01.01.1990)
    final dateRegex = RegExp(r'\b\d{2}[\/\-.]\d{2}[\/\-.]\d{4}\b');
    final dateMatches =
        dateRegex.allMatches(text).map((m) => m.group(0)!).toList();

    if (dateMatches.isNotEmpty) {
      // Heuristic: On a CIN, the first date is usually birthDate, second is expiryDate
      result['birthDate'] = dateMatches[0];
      if (dateMatches.length >= 2) {
        // Expiry date is usually the later one if they are both in the future/past mix,
        // but on CIN it's simply the second one found.
        result['expiryDate'] = dateMatches[1];
      }
    }

    // 3. Lines to skip (not names)
    final skipKeywords = [
      'ROYAUME',
      'MAROC',
      'CARTE',
      'NATIONALE',
      'IDENTITE',
      'IDENTITY',
      'NATIONAL',
      'CARD',
      'VALABLE',
      'VALID',
      'EXPIRE',
      'DATE',
      'LIEU',
      'PLACE',
      'BORN',
      'NÉ',
      'المملكة',
      'المغربية',
      'بطاقة',
      'التعريف',
      'الوطنية',
    ];

    bool isSkippable(String line) {
      if (skipKeywords.any((k) => line.toUpperCase().contains(k.toUpperCase())))
        return true;
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

    // 4. Find name lines. On Moroccan CIN, the order varies depending on OCR output.
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

    // On the Moroccan CIN the given name is printed above the surname, and
    // neither carries a label. Multi-word given names stay on one line.
    if (latinNames.isNotEmpty) {
      result['firstName'] = latinNames[0];
    }
    if (latinNames.length >= 2) {
      result['lastName'] = latinNames[1];
    }

    if (arabicNames.isNotEmpty && (result['firstName'] ?? '').isEmpty) {
      result['firstName'] = arabicNames[0];
    }
    if (arabicNames.length >= 2 && (result['lastName'] ?? '').isEmpty) {
      result['lastName'] = arabicNames[1];
    }

    // 5. Extract address (usually after birth info)
    for (int i = 0; i < lines.length; i++) {
      final upper = lines[i].toUpperCase();
      if (upper.contains('NÉ') ||
          upper.contains('NEE') ||
          upper.contains('BORN') ||
          dateRegex.hasMatch(lines[i])) {
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

  /// Parse contract-like document text for client (CIN, names), dates and amount.
  /// Returns map with: cin, firstName, lastName, startDate (dd/MM/yyyy), endDate, amount (string).
  Map<String, String> parseContractDocument(String text) {
    final result = <String, String>{
      'cin': '',
      'firstName': '',
      'lastName': '',
      'startDate': '',
      'endDate': '',
      'amount': '',
    };
    if (text.trim().isEmpty) return result;
    final cinData = parseCINData(text);
    result['cin'] = cinData['cin'] ?? '';
    result['firstName'] = cinData['firstName'] ?? '';
    result['lastName'] = cinData['lastName'] ?? '';
    final dateRegex = RegExp(
        r'\b(\d{2}[\/\-]\d{2}[\/\-]\d{4}|\d{4}[\/\-]\d{2}[\/\-]\d{2})\b');
    final dates = dateRegex.allMatches(text).map((m) => m.group(0)!).toList();
    if (dates.isNotEmpty) result['startDate'] = dates[0];
    if (dates.length >= 2) result['endDate'] = dates[1];
    final madRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:MAD|DH|د\.م\.ج)?',
        caseSensitive: false);
    final madMatch = madRegex.firstMatch(text);
    if (madMatch != null)
      result['amount'] = madMatch.group(1)!.replaceAll(',', '.');
    return result;
  }

  Map<String, String> parseLicenseData(String text) {
    final result = <String, String>{
      'licenseNumber': '',
      'firstName': '',
      'lastName': '',
      'cin': '',
      'expiryDate': '',
    };
    if (text.trim().isEmpty) return result;
    final lines = text
        .split(RegExp(r'\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final dateRegex = RegExp(r'\b\d{2}[\/\-.]\d{2}[\/\-.]\d{4}\b');

    // Only accept a date the card explicitly labels as an expiry. The permis
    // prints an ISSUE date ("délivré à Settat / Le 09/06/2019"); reading
    // that as the expiry makes a valid licence look expired and raises a false
    // warning on every scan. An empty field is safer than a wrong one.
    final expiryLabel =
        RegExp(r'valable|jusqu|expir|validit', caseSensitive: false);
    // Wording that marks a date as the date of ISSUE, never an expiry.
    final issueLabel =
        RegExp(r'd[ée]livr|deliver|issued|^\s*le\b', caseSensitive: false);

    for (var i = 0; i < lines.length; i++) {
      if (!expiryLabel.hasMatch(lines[i])) continue;
      for (var j = i; j < lines.length && j <= i + 1; j++) {
        // Never harvest a date sitting on, or directly after, an issue label.
        if (issueLabel.hasMatch(lines[j])) continue;
        if (j > 0 && issueLabel.hasMatch(lines[j - 1])) continue;
        final m = dateRegex.firstMatch(lines[j]);
        if (m != null) {
          result['expiryDate'] = m.group(0)!;
          break;
        }
      }
      if (result['expiryDate']!.isNotEmpty) break;
    }

    // Permit numbers look like 12/345678 — at least five digits after the
    // separator. Requiring five rules out the four-digit year in a date such
    // as 14/03/1990, whose "03/1990" fragment otherwise looks like a match.
    // The lookarounds stop the match starting or ending mid-date.
    final licenseRegex =
        RegExp(r'(?<![\d/.\-])\d{1,3}\s*[/\-]\s*\d{5,10}(?![\d/.\-])');

    // Prefer a number on a line that names the field, wherever it appears in
    // the recognised text, since OCR line order is not guaranteed.
    for (final line in lines) {
      final low = line.toLowerCase();
      if (low.contains('permis') ||
          low.contains('license') ||
          low.contains('n°')) {
        final match = licenseRegex.firstMatch(line);
        if (match != null) {
          result['licenseNumber'] =
              match.group(0)!.replaceAll(RegExp(r'\s'), '');
          break;
        }
      }
    }

    // Otherwise fall back to the first well-formed permit number anywhere.
    if (result['licenseNumber']!.isEmpty) {
      final match = licenseRegex.firstMatch(text);
      if (match != null) {
        result['licenseNumber'] = match.group(0)!.replaceAll(RegExp(r'\s'), '');
      }
    }

    // The permis also prints the holder's CIN under N.C.N.I.E. — a reliable
    // cross-check against the identity card.
    final cinMatch = RegExp(r'\b[A-Z]{1,2}\d{5,10}\b', caseSensitive: false)
        .firstMatch(text);
    if (cinMatch != null) {
      result['cin'] = cinMatch.group(0)!.toUpperCase();
    }

    // Names on the permis carry French labels, but OCR may keep the value on
    // the label line or push it to the line below, so both are checked.
    final arabic = RegExp(r'[\u0600-\u06FF]');
    final latinName = RegExp(r"^[A-ZÀ-Ÿ][A-ZÀ-Ÿ\s\-']+$");
    // Pre-printed wording on the card. ML Kit groups text by position rather
    // than reading order, so a label can end up next to the document title -
    // without this guard 'PERMIS DE CONDUIRE' gets taken as the given name.
    final heading = RegExp(
      r'ROYAUME|MAROC|PERMIS|CONDUIRE|LICENCE|LICENSE|DRIVING|AGENCE|'
      r'NATIONALE|SECURITE|ROUTIERE|DIRECTEUR|CARTE|IDENTITE',
      caseSensitive: false,
    );

    bool isNameCandidate(String s) =>
        latinName.hasMatch(s) && !heading.hasMatch(s);

    String valueForLabelAt(int index) {
      final sameLine = lines[index]
          .replaceAll(arabic, '')
          .replaceAll(RegExp(r'pr[ée]nom|nom|name', caseSensitive: false), '')
          .replaceAll(RegExp(r'^[\s:/\\-]+'), '')
          .trim();
      if (isNameCandidate(sameLine)) return sameLine;

      for (var j = index + 1; j < lines.length && j <= index + 2; j++) {
        final candidate = lines[j].replaceAll(arabic, '').trim();
        if (isNameCandidate(candidate)) return candidate;
      }
      return '';
    }

    for (var i = 0; i < lines.length; i++) {
      final low = lines[i].toLowerCase();
      // 'prénom' contains 'nom', so the given-name label must win first.
      final isGivenName = low.contains('prénom') || low.contains('prenom');
      final isSurname = !isGivenName && RegExp(r'\bnom\b').hasMatch(low);

      if (isGivenName && result['firstName']!.isEmpty) {
        result['firstName'] = valueForLabelAt(i);
      } else if (isSurname && result['lastName']!.isEmpty) {
        result['lastName'] = valueForLabelAt(i);
      }
    }

    // The field labels are printed very small and are routinely dropped
    // entirely from a phone photo - the 'Nom' label especially - so labels
    // cannot be relied on. Fall back to the card's fixed structure: the given
    // name and surname are the uppercase Latin lines above the birth date,
    // while the birthplace is the line below it.
    if (result['firstName']!.isEmpty || result['lastName']!.isEmpty) {
      final firstDateLine = lines.indexWhere(dateRegex.hasMatch);
      final beforeDate = firstDateLine == -1 ? lines.length : firstDateLine;

      final candidates = <String>[];
      for (var i = 0; i < beforeDate; i++) {
        final candidate = lines[i].replaceAll(arabic, '').trim();
        if (isNameCandidate(candidate)) candidates.add(candidate);
      }

      if (result['firstName']!.isEmpty && candidates.isNotEmpty) {
        result['firstName'] = candidates[0];
      }
      if (result['lastName']!.isEmpty && candidates.length >= 2) {
        result['lastName'] = candidates[1];
      }
    }
    return result;
  }
}
