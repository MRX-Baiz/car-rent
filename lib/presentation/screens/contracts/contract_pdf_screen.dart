import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class ContractPdfScreen extends StatefulWidget {
  const ContractPdfScreen(
      {super.key,
      required this.bytes,
      required this.title,
      this.confirmLabel,
      this.confirmationText});

  final Uint8List bytes;
  final String title;
  final String? confirmLabel;
  final String? confirmationText;

  @override
  State<ContractPdfScreen> createState() => _ContractPdfScreenState();
}

class _ContractPdfScreenState extends State<ContractPdfScreen> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(children: [
          Expanded(
              child: PdfPreview(
            build: (_) async => widget.bytes,
            canChangePageFormat: false,
            canChangeOrientation: false,
            allowPrinting: false,
            allowSharing: false,
            canDebug: false,
          )),
          if (widget.confirmLabel != null)
            SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CheckboxListTile(
                      value: _confirmed,
                      onChanged: (value) =>
                          setState(() => _confirmed = value ?? false),
                      title: Text(widget.confirmationText ??
                          'J’ai lu le contrat et accepté ses conditions.'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    FilledButton(
                      onPressed: _confirmed
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      child: Text(widget.confirmLabel!),
                    ),
                  ]),
                )),
        ]),
      );
}
