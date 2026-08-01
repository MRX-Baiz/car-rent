import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'ocr_service.dart';

/// "Importer CIN" / "Importer Permis" buttons backed by on-device OCR.
/// Parses the recognized text, then calls [onCINScanned] or [onLicenseScanned].
class OcrScanWidget extends StatefulWidget {
  const OcrScanWidget({
    super.key,
    required this.ocrService,
    required this.onCINScanned,
    required this.onLicenseScanned,
    this.isEnabled = true,
  });

  final OcrService ocrService;
  final void Function(Map<String, String> data) onCINScanned;
  final void Function(Map<String, String> data) onLicenseScanned;
  final bool isEnabled;

  @override
  State<OcrScanWidget> createState() => _OcrScanWidgetState();
}

class _OcrScanWidgetState extends State<OcrScanWidget> {
  bool _isLoading = false;

  static const _allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf', 'docx', 'doc'];

  Future<String?> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }

  Future<void> _importCIN() async {
    if (_isLoading || !widget.isEnabled) return;
    final path = await _pickFile();
    if (path == null || !mounted) return;
    final file = File(path);
    if (!await file.exists()) return;
    setState(() => _isLoading = true);
    try {
      String text;
      try {
        text = await widget.ocrService.extractText(path);
      } catch (_) {
        text = '';
      }
      if (text.trim().isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun texte extrait. Essayez une image plus nette ou un autre fichier.',
            ),
          ),
        );
        return;
      }
      final data = widget.ocrService.parseCINData(text);
      if (mounted) {
        widget.onCINScanned(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informations extraites avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur extraction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importLicense() async {
    if (_isLoading || !widget.isEnabled) return;
    final path = await _pickFile();
    if (path == null || !mounted) return;
    final file = File(path);
    if (!await file.exists()) return;
    setState(() => _isLoading = true);
    try {
      String text;
      try {
        text = await widget.ocrService.extractText(path);
      } catch (_) {
        text = '';
      }
      if (text.trim().isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun texte extrait. Essayez une image plus nette ou un autre fichier.',
            ),
          ),
        );
        return;
      }
      final data = widget.ocrService.parseLicenseData(text);
      if (mounted) {
        widget.onLicenseScanned(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informations extraites avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur extraction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.isEnabled && !_isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.offline_bolt_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'OCR intégré · fonctionne hors ligne',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? _importCIN : null,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Importer CIN'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? _importLicense : null,
                icon: const Icon(Icons.credit_card),
                label: const Text('Importer Permis'),
              ),
            ),
          ],
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}
