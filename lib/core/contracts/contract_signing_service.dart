import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../pdf/contract_pdf_generator.dart';
import '../storage/media_store.dart';
import '../../data/models/contract_document.dart';
import '../../data/models/contract_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/contract_repository.dart';
import '../../data/repositories/vehicle_repository.dart';

class ContractSigningService {
  static final instance = ContractSigningService();

  static String terms(ContractModel c) => c.signingTermsJson;

  Future<ContractDocument?> getDocument(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db
        .query('contract_documents', where: 'contract_id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : ContractDocument(rows.single);
  }

  Future<ContractDocument> prepare(int id) async {
    final existing = await getDocument(id);
    if (existing != null) return existing;
    final contract = await ContractRepository.instance.getContractById(id);
    if (contract == null) throw StateError('Contrat introuvable.');
    final vehicle =
        await VehicleRepository.instance.getVehicleById(contract.vehicleId);
    final client =
        await ClientRepository.instance.getClientById(contract.primaryDriverId);
    if (vehicle == null || client == null) {
      throw StateError('Véhicule ou client introuvable.');
    }
    final secondary = contract.secondaryDriverId == null
        ? null
        : await ClientRepository.instance
            .getClientById(contract.secondaryDriverId!);
    final bytes = await ContractPdfGenerator().buildContractBytes(
      contract: contract,
      vehicle: vehicle,
      primaryDriver: client,
      secondaryDriver: secondary,
    );
    final path = await _save(bytes, 'contrat_original', 'pdf');
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        final current =
            await txn.query('contracts', where: 'id = ?', whereArgs: [id]);
        if (current.isEmpty ||
            terms(ContractModel.fromMap(current.single)) != terms(contract)) {
          throw StateError('Le contrat a changé. Ouvrez-le à nouveau.');
        }
        await txn.insert('contract_documents', {
          'contract_id': id,
          'original_path': path,
          'original_hash': sha256.convert(bytes).toString(),
          'prepared_at': DateTime.now().toIso8601String(),
          'signer_name': client.fullName,
          'signer_cin': client.cin,
          'signer_license': client.licenseNumber,
          'terms_json': terms(contract),
        });
      });
    } catch (_) {
      await MediaStore.instance.delete(path);
      rethrow;
    }
    return (await getDocument(id))!;
  }

  Future<File> documentFile(ContractDocument document,
      {bool original = false}) async {
    final useSigned = !original && document.isSigned;
    final file = MediaStore.instance
        .resolveFile(useSigned ? document.signedPath : document.originalPath);
    if (file == null) {
      throw StateError(
          'PDF introuvable. Restaurez une sauvegarde contenant ce document.');
    }
    final expected = useSigned ? document.signedHash : document.originalHash;
    if (sha256.convert(await file.readAsBytes()).toString() != expected) {
      throw StateError(
          'Le PDF enregistré a été modifié. Utilisez une sauvegarde intacte.');
    }
    return file;
  }

  Future<void> signOnDevice(int id, Uint8List signature,
      {required bool accepted}) async {
    if (!accepted || signature.isEmpty) {
      throw StateError('Lecture, accord et signature requis.');
    }
    final record = await prepare(id);
    if (record.isSigned) {
      throw StateError('Ce contrat possède déjà un PDF signé.');
    }
    final original = await documentFile(record, original: true);
    final time = DateTime.now();
    final bytes =
        await stampSignature(await original.readAsBytes(), signature, time);
    final signaturePath = await _save(signature, 'signature_client', 'png');
    try {
      await _finish(record, bytes, 'local', time, signaturePath: signaturePath);
    } catch (_) {
      await MediaStore.instance.delete(signaturePath);
      rethrow;
    }
  }

  static Future<Uint8List> stampSignature(
      Uint8List original, Uint8List signature, DateTime time) async {
    final pdf = PdfDocument(inputBytes: original);
    try {
      PdfField? field;
      for (var i = 0; i < pdf.form.fields.count; i++) {
        if (pdf.form.fields[i].name == 'client_signature') {
          field = pdf.form.fields[i];
        }
      }
      if (field == null || field.page == null) {
        throw StateError('Zone de signature absente.');
      }
      final bounds = field.bounds;
      final page = field.page!;
      final bitmap = PdfBitmap(signature);
      final imageHeight = bounds.height - 22;
      final scale =
          (bounds.width / bitmap.width).clamp(0.0, imageHeight / bitmap.height);
      page.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(bounds.left, bounds.top, bitmap.width * scale,
              bitmap.height * scale));
      page.graphics.drawString(
        'Signé le ${DateFormat('dd/MM/yyyy HH:mm').format(time)} (heure du téléphone)',
        PdfStandardFont(PdfFontFamily.helvetica, 7),
        bounds:
            Rect.fromLTWH(bounds.left, bounds.bottom - 18, bounds.width, 18),
      );
      // This is a captured handwritten signature, not a certificate signature.
      pdf.form.fields.remove(field);
      return Uint8List.fromList(await pdf.save());
    } finally {
      pdf.dispose();
    }
  }

  Future<void> validateReturnedPdf(int id, Uint8List bytes) async {
    if (bytes.length > 30 * 1024 * 1024) {
      throw StateError('PDF trop volumineux (maximum 30 Mo).');
    }
    final record = await prepare(id);
    if (record.isSigned) {
      throw StateError('Ce contrat possède déjà un PDF signé.');
    }
    if (sha256.convert(bytes).toString() == record.originalHash) {
      throw StateError(
          'Ce fichier est le PDF original. Choisissez la copie signée.');
    }
    final contract = await ContractRepository.instance.getContractById(id);
    PdfDocument? pdf;
    try {
      pdf = PdfDocument(inputBytes: bytes);
      if (pdf.pages.count == 0) throw const FormatException();
      final text = PdfTextExtractor(pdf).extractText();
      if (contract == null || !text.contains(contract.contractNumber)) {
        throw StateError(
            'Le numéro de ce contrat est absent du PDF. Choisissez le bon fichier.');
      }
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError(
          'PDF illisible ou protégé. Demandez une copie PDF accessible au client.');
    } finally {
      pdf?.dispose();
    }
  }

  Future<void> importSignedPdf(int id, Uint8List bytes,
      {required bool reviewed}) async {
    if (!reviewed) {
      throw StateError(
          'Vérifiez le contrat et la signature avant de confirmer.');
    }
    await validateReturnedPdf(id, bytes);
    final record = (await getDocument(id))!;
    // Preserve returned bytes exactly, including any annotations/certificates.
    await _finish(record, bytes, 'imported', DateTime.now());
  }

  Future<void> _finish(
      ContractDocument record, Uint8List bytes, String method, DateTime time,
      {String? signaturePath}) async {
    final path = await _save(bytes, 'contrat_signe', 'pdf');
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        final rows = await txn.query('contracts',
            where: 'id = ?', whereArgs: [record.contractId]);
        if (rows.isEmpty ||
            terms(ContractModel.fromMap(rows.single)) !=
                record.data['terms_json']) {
          throw StateError('Le contrat a changé depuis la préparation du PDF.');
        }
        final changed = await txn.update(
            'contract_documents',
            {
              'signed_path': path,
              'signed_hash': sha256.convert(bytes).toString(),
              'signature_path': signaturePath,
              'method': method,
              'recorded_at': time.toIso8601String(),
            },
            where: 'contract_id = ? AND signed_path IS NULL',
            whereArgs: [record.contractId]);
        if (changed != 1) throw StateError('Le PDF signé est déjà enregistré.');
      });
    } catch (_) {
      await MediaStore.instance.delete(path);
      rethrow;
    }
  }

  Future<String> _save(Uint8List bytes, String prefix, String extension) async {
    final name = '${prefix}_${const Uuid().v4()}.$extension';
    final file = File(p.join(MediaStore.instance.directory.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return name;
  }
}
