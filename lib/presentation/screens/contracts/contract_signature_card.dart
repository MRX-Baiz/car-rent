import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
        setState(() => _loadError = 'Impossible de charger les documents.');
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
            .showSnackBar(SnackBar(content: Text('$error')));
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
    await _preview(await file.readAsBytes(),
        original || !doc.isSigned ? 'Contrat à signer' : 'Contrat signé');
  }

  Future<void> _sign() async {
    final doc = await _service.prepare(widget.contractId);
    final file = await _service.documentFile(doc, original: true);
    final accepted = await _preview(await file.readAsBytes(), 'Lire le contrat',
        confirm: 'Continuer et signer');
    if (!accepted || !mounted) return;
    final signature = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
            builder: (_) => ClientSignatureScreen(clientName: doc.signerName)));
    if (signature == null) return;
    await _service.signOnDevice(widget.contractId, signature, accepted: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Signature et PDF signés enregistrés.')));
    }
  }

  Future<void> _share({bool original = false}) async {
    final doc = await _service.prepare(widget.contractId);
    final file = await _service.documentFile(doc, original: original);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
        text: original || !doc.isSigned
            ? 'Merci de lire ce contrat, de le signer avec une application PDF '
                'comme Adobe Acrobat Reader (Remplir et signer), puis de nous renvoyer le PDF signé.'
            : 'Votre contrat de location signé.');
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false);
    if (picked == null) return;
    final item = picked.files.single;
    if (item.size > 30 * 1024 * 1024) {
      throw StateError('PDF trop volumineux (maximum 30 Mo).');
    }
    final bytes = item.bytes ??
        (item.path == null ? null : await File(item.path!).readAsBytes());
    if (bytes == null) {
      throw StateError(
          'Fichier inaccessible. Enregistrez-le sur le téléphone.');
    }
    await _service.validateReturnedPdf(widget.contractId, bytes);
    final reviewed = await _preview(bytes, 'Vérifier le PDF reçu',
        confirm: 'Enregistrer le PDF signé',
        explanation:
            'J’ai vérifié le client, les dates, le montant, les conditions et la signature. '
            'L’application ne vérifie pas automatiquement l’identité du signataire.');
    if (!reviewed) return;
    await _service.importSignedPdf(widget.contractId, bytes, reviewed: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF signé reçu et enregistré.')));
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
                child: Text('Signature du client',
                    style: theme.textTheme.titleMedium),
              ),
              StatusChip(
                label: signed ? 'Signé' : 'À signer',
                tone: signed ? AppTone.success : AppTone.warning,
                icon: signed ? Icons.check : Icons.edit_outlined,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            signed
                ? (imported
                    ? 'PDF signé importé • vérifié par vous'
                    : 'Signé sur ce téléphone')
                : _document == null
                    ? 'Le PDF sera préparé à la première ouverture.'
                    : 'PDF prêt • en attente de signature',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          if (_document?.recordedAt != null)
            Text(
              '${imported ? 'Reçu' : 'Signé'} le '
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
            Text(_loadError!),
            TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Réessayer')),
          ] else if (!signed) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: disabled ? null : () => _run(_sign),
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Signer sur ce téléphone'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: disabled ? null : () => _run(() => _view()),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Voir le contrat PDF'),
            ),
            const Divider(height: 28),
            Text('Signature à distance', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Le client doit utiliser une application PDF, comme Adobe Acrobat Reader '
              '(Remplir et signer). Envoyez le PDF par WhatsApp ou e-mail. '
              'Le client le signe et vous renvoie le fichier signé.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  disabled ? null : () => _run(() => _share(original: true)),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Envoyer au client pour signature'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: disabled ? null : () => _run(_import),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Importer le PDF signé'),
            ),
            const SizedBox(height: 10),
            Text(
              'Le premier PDF préparé est conservé tel quel. Vérifiez les informations '
              'avant de continuer. Les paiements et la clôture restent disponibles.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ] else ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: disabled ? null : () => _run(() => _view()),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Voir le PDF signé'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: disabled ? null : () => _run(() => _share()),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Partager le PDF signé'),
            ),
            TextButton(
              onPressed:
                  disabled ? null : () => _run(() => _view(original: true)),
              child: const Text('Voir le PDF original'),
            ),
            Text(
              'Le PDF signé conserve les montants au moment de sa création. '
              'Consultez les paiements du contrat pour le solde actuel.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
