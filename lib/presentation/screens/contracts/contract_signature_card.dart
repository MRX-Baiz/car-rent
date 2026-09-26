import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/contracts/contract_signing_service.dart';
import '../../../data/models/contract_document.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/status_chip.dart';
import 'client_signature_screen.dart';
import 'contract_pdf_screen.dart';

class ContractSignatureCard extends StatefulWidget {
  const ContractSignatureCard(
      {super.key, required this.contractId, this.onChanged});
  final int contractId;

  /// Called after the document state was re-read, so the page can refresh
  /// anything that depends on whether the contract is signed.
  final VoidCallback? onChanged;

  @override
  State<ContractSignatureCard> createState() => _ContractSignatureCardState();
}

class _ContractSignatureCardState extends State<ContractSignatureCard> {
  final _service = ContractSigningService.instance;
  ContractDocument? _document;
  bool _busy = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final document = await _service.getDocument(widget.contractId);
      if (mounted) {
        setState(() {
          _document = document;
          _loadError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = AppCopy.unableToLoadDocuments);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(context.trError(error))));
      }
    } finally {
      if (mounted) {
        await _load();
        widget.onChanged?.call();
      }
    }
  }

  Future<bool> _preview(Uint8List bytes, String title,
      {String? confirm, String? explanation}) async {
    if (!mounted) return false;
    return await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => ContractPdfScreen(
                  bytes: bytes,
                  title: title,
                  confirmLabel: confirm,
                  confirmationText: explanation,
                ))) ??
        false;
  }

  Future<void> _view({bool original = false}) async {
    final doc = await _service.prepare(widget.contractId);
    final file = await _service.documentFile(doc, original: original);
    await _preview(
        await file.readAsBytes(),
        original || !doc.isSigned
            ? AppCopy.contractToSign
            : AppCopy.signedContract);
  }

  Future<void> _sign() async {
    final doc = await _service.prepare(widget.contractId);
    final file = await _service.documentFile(doc, original: true);
    final accepted = await _preview(
        await file.readAsBytes(), AppCopy.readTheContract,
        confirm: AppCopy.continueAndSign);
    if (!accepted || !mounted) return;
    final signature = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
            builder: (_) => ClientSignatureScreen(clientName: doc.signerName)));
    if (signature == null) return;
    await _service.signOnDevice(widget.contractId, signature, accepted: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText(AppCopy.signatureAndSignedPDFSaved)));
    }
  }

  Future<void> _share({bool original = false}) async {
    final doc = await _service.prepare(widget.contractId);
    final file = await _service.documentFile(doc, original: original);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
        text: original || !doc.isSigned
            ? context.tr(AppCopy.pleaseReadThisContractSignItWithA)
            : context.tr(AppCopy.yourSignedRentalContract));
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false);
    if (picked == null) return;
    final item = picked.files.single;
    if (item.size > 30 * 1024 * 1024) {
      throw StateError(AppCopy.pdfTooLargeMaximum30MB);
    }
    final bytes = item.bytes ??
        (item.path == null ? null : await File(item.path!).readAsBytes());
    if (bytes == null) {
      throw StateError(AppCopy.fileInaccessibleSaveItOnThePhone);
    }
    await _service.validateReturnedPdf(widget.contractId, bytes);
    final reviewed = await _preview(bytes, AppCopy.checkReceivedPDF,
        confirm: AppCopy.saveSignedPDF,
        explanation: AppCopy.iHaveCheckedTheClientDatesAmountTerms);
    if (!reviewed) return;
    await _service.importSignedPdf(widget.contractId, bytes, reviewed: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText(AppCopy.signedPDFReceivedAndSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signed = _document?.isSigned == true;
    final imported = _document?.method == 'imported';
    final disabled = _busy;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(AppCopy.clientSignature,
                    style: theme.textTheme.titleMedium),
              ),
              StatusChip(
                label: signed ? AppCopy.signed : AppCopy.toSign,
                tone: signed ? AppTone.success : AppTone.warning,
                icon: signed ? Icons.check : Icons.edit_outlined,
              ),
            ],
          ),
          const SizedBox(height: 6),
          AppText(
            signed
                ? (imported
                    ? AppCopy.signedPDFImportedVerifiedByYou
                    : AppCopy.signedOnThisPhone)
                : _document == null
                    ? AppCopy.thePDFWillBePreparedWhenItIs
                    : AppCopy.pdfReadyAwaitingSignature,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          if (_document?.recordedAt != null)
            AppText(
              '${context.tr(imported ? AppCopy.received : AppCopy.signed)} · '
              '${DateFormat('dd/MM/yyyy HH:mm').format(_document!.recordedAt!)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (_loadError != null) ...[
            const SizedBox(height: 8),
            AppText(_loadError!),
            TextButton(
                onPressed: _busy ? null : _load,
                child: const AppText(AppCopy.tryAgain)),
          ] else if (!signed) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: disabled ? null : () => _run(_sign),
              icon: const Icon(Icons.draw_outlined),
              label: const AppText(AppCopy.signOnThisPhone),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: disabled ? null : () => _run(() => _view()),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const AppText(AppCopy.viewContractPDF),
            ),
            const Divider(height: 28),
            AppText(AppCopy.remoteSignature, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            AppText(
              AppCopy.theClientMustUseAPDFAppSuch,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  disabled ? null : () => _run(() => _share(original: true)),
              icon: const Icon(Icons.share_outlined),
              label: const AppText(AppCopy.sendToClientForSignature),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: disabled ? null : () => _run(_import),
              icon: const Icon(Icons.file_download_outlined),
              label: const AppText(AppCopy.importSignedPDF),
            ),
            const SizedBox(height: 10),
            AppText(
              AppCopy.theFirstPreparedPDFIsKeptUnchangedCheck,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ] else ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: disabled ? null : () => _run(() => _view()),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const AppText(AppCopy.viewSignedPDF),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: disabled ? null : () => _run(() => _share()),
              icon: const Icon(Icons.share_outlined),
              label: const AppText(AppCopy.shareSignedPDF),
            ),
            TextButton(
              onPressed:
                  disabled ? null : () => _run(() => _view(original: true)),
              child: const AppText(AppCopy.viewOriginalPDF),
            ),
            AppText(
              AppCopy.theSignedPDFKeepsTheAmountsFromWhen,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
