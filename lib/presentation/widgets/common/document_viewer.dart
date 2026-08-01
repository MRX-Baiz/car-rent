import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen viewer for a scanned document, with pinch-to-zoom and pan.
///
/// Scanned CIN and permis photos are small and often taken at an angle, so the
/// thumbnails on the detail screens are unreadable. Tapping one opens this.
class DocumentViewer extends StatelessWidget {
  const DocumentViewer({
    super.key,
    required this.imagePath,
    required this.title,
  });

  final String imagePath;
  final String title;

  /// Opens the viewer for [imagePath]; does nothing if the file is missing.
  static Future<void> open(
    BuildContext context, {
    required String? imagePath,
    required String title,
  }) async {
    if (imagePath == null || imagePath.isEmpty) return;
    if (!File(imagePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image introuvable : $title')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewer(imagePath: imagePath, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: SafeArea(
        child: Center(
          child: Hero(
            tag: 'document-$imagePath',
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 6,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, _, __) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Impossible d\'ouvrir cette image.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
