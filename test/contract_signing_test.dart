import 'dart:io';
import 'dart:typed_data';

import 'package:car_rent_manager/core/backup/backup_service.dart';
import 'package:car_rent_manager/core/contracts/contract_signing_service.dart';
import 'package:car_rent_manager/core/database/database_helper.dart';
import 'package:car_rent_manager/core/storage/media_store.dart';
import 'package:car_rent_manager/data/models/contract_model.dart';
import 'package:car_rent_manager/data/repositories/contract_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = ContractSigningService.instance;
  late Directory root;
  late ContractModel contract;
  late Uint8List signature;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('contract-signing-');
    await databaseFactory.setDatabasesPath(root.path);
    final media = await Directory(p.join(root.path, 'media')).create();
    MediaStore.instance.debugSetDirectory(media);
    signature = await File('test/fixtures/sample_signature.png').readAsBytes();
    final db = await DatabaseHelper.instance.database;
    final now = DateTime(2026, 9, 19, 22, 17);
    final dates = {
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String()
    };
    final vehicle = await db.insert('vehicles', {
      ...dates,
      'brand': 'Renault',
      'model': 'Clio',
      'registration_number': 'TEST-123',
      'year': 2025,
    });
    final client = await db.insert('clients', {
      ...dates,
      'first_name': 'Client',
      'last_name': 'Exemple',
      'cin': 'TEST-CIN',
      'license_number': 'TEST-PERMIS',
      'phone': '0600000000',
    });
    await db.insert(
        'app_settings', {'key': 'company_name', 'value': 'Agence Exemple'});
    await File(p.join(media.path, 'agency.png')).writeAsBytes(signature);
    await db.insert(
        'app_settings', {'key': 'company_signature', 'value': 'agency.png'});
    final value = ContractModel(
        contractNumber: 'CTR-20260919-0001',
        vehicleId: vehicle,
        primaryDriverId: client,
        startDate: now,
        expectedReturnDate: now.add(const Duration(days: 3)),
        totalPrice: 900,
        amountPaid: 300,
        status: 'active',
        notes: 'Retour avec le plein.',
        createdAt: now,
        updatedAt: now);
    final id = await ContractRepository.instance.insertContract(value);
    contract = value.copyWith(id: id);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    await root.delete(recursive: true);
  });

  test(
      'on-device signing preserves original, includes signature, time and real terms',
      () async {
    final original = await service.prepare(contract.id!);
    final originalFile = await service.documentFile(original);
    final originalBytes = await originalFile.readAsBytes();
    final unsigned = PdfDocument(inputBytes: originalBytes);
    expect(unsigned.form.fields.count, 1);
    expect(unsigned.form.fields[0].name, 'client_signature');
    final text = PdfTextExtractor(unsigned)
        .extractText()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(text, contains('18:00'));
    expect(text, contains('900.00 MAD'));
    unsigned.dispose();

    await expectLater(
        service.signOnDevice(contract.id!, signature, accepted: false),
        throwsStateError);
    await service.signOnDevice(contract.id!, signature, accepted: true);
    final signed = (await service.getDocument(contract.id!))!;
    expect(signed.method, 'local');
    final signedBytes =
        await (await service.documentFile(signed)).readAsBytes();
    expect(await originalFile.readAsBytes(), originalBytes);
    expect(signedBytes, isNot(originalBytes));
    final pdf = PdfDocument(inputBytes: signedBytes);
    expect(pdf.form.fields.count, 0);
    expect(PdfTextExtractor(pdf).extractText().replaceAll(RegExp(r'\s+'), ' '),
        contains('Signé le'));
    pdf.dispose();
    await expectLater(
        service.signOnDevice(contract.id!, signature, accepted: true),
        throwsStateError);

    final preview =
        await Directory('build/signing-preview').create(recursive: true);
    await File(p.join(preview.path, 'original.pdf'))
        .writeAsBytes(originalBytes);
    await File(p.join(preview.path, 'signed.pdf')).writeAsBytes(signedBytes);
  });

  test(
      'import requires review, rejects original/bad/wrong PDF and preserves returned bytes',
      () async {
    final record = await service.prepare(contract.id!);
    final bytes = await (await service.documentFile(record)).readAsBytes();
    await expectLater(
        service.validateReturnedPdf(contract.id!, bytes), throwsStateError);
    await expectLater(
        service.validateReturnedPdf(
            contract.id!, Uint8List.fromList([1, 2, 3])),
        throwsStateError);
    final unrelated = PdfDocument();
    unrelated.pages.add();
    final wrong = Uint8List.fromList(await unrelated.save());
    unrelated.dispose();
    await expectLater(
        service.validateReturnedPdf(contract.id!, wrong), throwsStateError);
    final returned = await ContractSigningService.stampSignature(
        bytes, signature, DateTime(2026, 9, 20));
    await expectLater(
        service.importSignedPdf(contract.id!, returned, reviewed: false),
        throwsStateError);
    await service.importSignedPdf(contract.id!, returned, reviewed: true);
    final saved = (await service.getDocument(contract.id!))!;
    expect(saved.method, 'imported');
    expect(await (await service.documentFile(saved)).readAsBytes(), returned);
    await expectLater(
        service.importSignedPdf(contract.id!, returned, reviewed: true),
        throwsStateError);
  });

  test(
      'frozen terms cannot change, payments and closing preserve the signed PDF',
      () async {
    await service.signOnDevice(contract.id!, signature, accepted: true);
    final record = (await service.getDocument(contract.id!))!;
    final before = await (await service.documentFile(record)).readAsBytes();
    await expectLater(
        ContractRepository.instance
            .updateContract(contract.copyWith(totalPrice: 1000)),
        throwsA(isA<Exception>()));
    await ContractRepository.instance
        .addPaymentAndUpdateContract(contract.id!, 600);
    await ContractRepository.instance
        .closeContract(contract.id!, DateTime(2026, 9, 22));
    final current =
        (await ContractRepository.instance.getContractById(contract.id!))!;
    expect(current.amountPaid, 900);
    expect(current.status, 'completed');
    expect(await (await service.documentFile(record)).readAsBytes(), before);
  });

  test(
      'backup restores original, signed PDF and captured signature after media deletion',
      () async {
    await service.signOnDevice(contract.id!, signature, accepted: true);
    final record = (await service.getDocument(contract.id!))!;
    final signedBytes =
        await (await service.documentFile(record)).readAsBytes();
    final backup = await BackupService.instance
        .createBackup(outputDirectory: root, workingDirectory: root);
    await MediaStore.instance.directory.delete(recursive: true);
    await ContractRepository.instance.deleteContract(contract.id!);
    await BackupService.instance.restoreBackup(backup, workingDirectory: root);
    final restored = (await service.getDocument(contract.id!))!;
    expect(await (await service.documentFile(restored)).readAsBytes(),
        signedBytes);
    expect(
        await (await service.documentFile(restored, original: true)).exists(),
        isTrue);
    expect(
        await MediaStore.instance
            .resolveFile(restored.data['signature_path'] as String)!
            .readAsBytes(),
        signature);
  });

  test('database v5 upgrade preserves contracts and adds later storage',
      () async {
    final db = await DatabaseHelper.instance.database;
    await db.execute('DROP TABLE contract_documents');
    await db.setVersion(5);
    await DatabaseHelper.instance.close();
    final upgraded = await DatabaseHelper.instance.database;
    expect(await upgraded.getVersion(), 10);
    expect(await upgraded.query('contracts'), hasLength(1));
    expect(await service.getDocument(contract.id!), isNull);
    expect((await service.prepare(contract.id!)).isSigned, isFalse);
  });

  test('a modified stored PDF is reported instead of shared', () async {
    final record = await service.prepare(contract.id!);
    final file = await service.documentFile(record);
    await file.writeAsBytes([1, 2, 3]);
    await expectLater(service.documentFile(record), throwsStateError);
  });
}
