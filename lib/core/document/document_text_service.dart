import 'dart:io';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf_text_extract/pdf_text_extract.dart';

import '../ocr/ocr_service.dart';

/// Extracts plain text from image, PDF, or Word (.docx) files for OCR parsing.
class DocumentTextService {
  DocumentTextService._();
  static final DocumentTextService instance = DocumentTextService._();

  final OcrService _ocrService = OcrService();

  static const _imageExtensions = ['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'];
  static const _pdfExtensions = ['pdf'];
  static const _docxExtensions = ['docx', 'doc'];

  /// Extracts raw text from [file] based on its extension.
  /// - Image: OCR (ML Kit on Android/iOS).
  /// - PDF: pdf_text_extract (Android/iOS); may fail on Windows.
  /// - Word: docx_to_text (all platforms).
  /// Returns empty string on failure or unsupported type.
  Future<String> extractTextFromFile(File file) async {
    if (!await file.exists()) return '';
    final ext = _extension(file.path).toLowerCase();
    if (_imageExtensions.contains(ext)) {
      return _ocrService.extractTextFromImage(file);
    }
    if (_pdfExtensions.contains(ext)) {
      return _extractTextFromPdf(file);
    }
    if (_docxExtensions.contains(ext)) {
      return _extractTextFromDocx(file);
    }
    return '';
  }

  String _extension(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0) return '';
    return path.substring(i + 1);
  }

  Future<String> _extractTextFromPdf(File file) async {
    try {
      final doc = await PDFDoc.fromFile(file);
      final text = await doc.text;
      return text ?? '';
    } catch (e) {
      if (kDebugMode) debugPrint('DocumentTextService PDF: $e');
      return '';
    }
  }

  Future<String> _extractTextFromDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return docxToText(bytes);
    } catch (e) {
      if (kDebugMode) debugPrint('DocumentTextService DOCX: $e');
      return '';
    }
  }

  /// Returns the list of allowed file extensions for picker (e.g. CIN / Permis).
  List<String> get allowedExtensions =>
      [..._imageExtensions, ..._pdfExtensions, ..._docxExtensions];

  /// Human-readable type filter label for file picker.
  String get fileTypeLabel =>
      'Image, PDF ou Word (.jpg, .png, .pdf, .docx)';
}
