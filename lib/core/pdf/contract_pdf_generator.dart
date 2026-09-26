import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../storage/media_store.dart';
import '../../data/models/client_model.dart';
import '../../data/models/contract_model.dart';
import '../../data/models/vehicle_model.dart';
import '../../data/repositories/app_settings_repository.dart';
import '../localization/app_localizations.dart';

class ContractPdfGenerator {
  String _languageCode = 'fr';
  final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');

  Future<File> generateContract({
    required ContractModel contract,
    required VehicleModel vehicle,
    required ClientModel primaryDriver,
    ClientModel? secondaryDriver,
  }) async {
    final bytes = await buildContractBytes(
        contract: contract,
        vehicle: vehicle,
        primaryDriver: primaryDriver,
        secondaryDriver: secondaryDriver);
    final output = await _getOutputFile(contract);
    await output.writeAsBytes(bytes, flush: true);
    return output;
  }

  Future<Uint8List> buildContractBytes({
    required ContractModel contract,
    required VehicleModel vehicle,
    required ClientModel primaryDriver,
    ClientModel? secondaryDriver,
  }) async {
    final doc = pw.Document();

    final creationDate = contract.createdAt;

    final repo = AppSettingsRepository.instance;
    _languageCode = await repo.getLanguage();
    final companyName = await repo.getCompanyName();
    final companyAddress = await repo.getCompanyAddress();
    final logoPath = await repo.getCompanyLogo();
    final signaturePath = await repo.getCompanySignature();

    // Both settings hold a media-store name; resolveSync also returns null for
    // a file that no longer exists, which the null checks below already handle.
    final logoFile = MediaStore.instance.resolveFile(logoPath);
    final signatureFile = MediaStore.instance.resolveFile(signaturePath);

    pw.MemoryImage? logoImage;
    if (logoFile != null) {
      try {
        logoImage = pw.MemoryImage(logoFile.readAsBytesSync());
      } catch (_) {}
    }

    pw.MemoryImage? signatureImage;
    if (signatureFile != null) {
      try {
        signatureImage = pw.MemoryImage(signatureFile.readAsBytesSync());
      } catch (_) {}
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(
              await rootBundle.load('assets/fonts/Roboto-Regular.ttf')),
          bold: pw.Font.ttf(
              await rootBundle.load('assets/fonts/Roboto-Bold.ttf')),
        ),
        build: (context) => [
          _buildHeader(contract, creationDate, logoImage, companyName),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _buildVehicleSection(vehicle)),
              pw.SizedBox(width: 10),
              pw.Expanded(
                  child: _buildClientSection(primaryDriver, secondaryDriver)),
            ],
          ),
          pw.SizedBox(height: 4),
          _buildRentalSection(contract, vehicle),
          pw.SizedBox(height: 4),
          _buildPaymentSummary(contract),
          if (contract.notes?.isNotEmpty == true) ...[
            pw.SizedBox(height: 8),
            pw.Text('${_t('Notes :')} ${contract.notes}',
                style: const pw.TextStyle(fontSize: 9)),
          ],
          pw.SizedBox(height: 24),
          _buildSignaturesSection(signatureImage),
          pw.SizedBox(height: 20),
          _buildCompanyAddressSection(companyAddress),
          pw.SizedBox(height: 8),
          _buildTermsAndConditions(),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> shareContract(File pdfFile) async {
    _languageCode = await AppSettingsRepository.instance.getLanguage();
    await Share.shareXFiles(
      [XFile(pdfFile.path)],
      text: _t('Contrat de location de véhicule'),
    );
  }

  /// Saves the PDF to the user's Documents folder and returns the saved path.
  Future<String> downloadContract(File pdfFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final contractsDir = Directory(p.join(docsDir.path, 'CarRent_Contracts'));
    if (!await contractsDir.exists())
      await contractsDir.create(recursive: true);
    final dest = File(p.join(contractsDir.path, p.basename(pdfFile.path)));
    if (p.normalize(pdfFile.path) != p.normalize(dest.path)) {
      await pdfFile.copy(dest.path);
    }
    return dest.path;
  }

  Future<void> printContract(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
    );
  }

  /// Rental handover times are presented using the agency's standard 18:00
  /// convention. This affects the PDF only; the stored contract dates retain
  /// the exact values entered by the operator.
  DateTime _standardizeTime(DateTime date) {
    if (date.hour >= 18) {
      return DateTime(date.year, date.month, date.day, 18, 0);
    }
    if (date.hour < 8) {
      final previousDay = date.subtract(const Duration(days: 1));
      return DateTime(
          previousDay.year, previousDay.month, previousDay.day, 18, 0);
    }
    return date;
  }

  pw.Widget _buildHeader(ContractModel contract, DateTime creationDate,
      pw.MemoryImage? logoImage, String companyName) {
    final standardizedDate = _standardizeTime(creationDate);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null) pw.Image(logoImage, height: 40),
                pw.SizedBox(height: 4),
                pw.Text(
                  companyName.isNotEmpty ? companyName : 'CarRent Manager',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF1A237E),
                  ),
                ),
              ],
            ),
            pw.Text(
              '${_t('Contrat n°:')} ${contract.contractNumber}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_t('Location de véhicule'),
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
                '${_t('Date:')} ${_dateTimeFormatter.format(standardizedDate)}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Container(height: 1, color: PdfColors.grey300),
      ],
    );
  }

  pw.Widget _buildVehicleSection(VehicleModel vehicle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(_t('Véhicule')),
        pw.SizedBox(height: 2),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(2),
          },
          children: [
            _tableRow(_t('Marque'), vehicle.brand, compact: true),
            _tableRow(_t('Modèle'), vehicle.model, compact: true),
            _tableRow(_t('Immat.'), vehicle.registrationNumber, compact: true),
            _tableRow(_t('Année'), vehicle.year.toString(), compact: true),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildClientSection(
    ClientModel primaryDriver,
    ClientModel? secondaryDriver,
  ) {
    final rows = <pw.TableRow>[
      _tableRow(_t('Nom'), primaryDriver.fullName, compact: true),
      _tableRow(_t('CIN'), primaryDriver.cin, compact: true),
      _tableRow(_t('Permis'), primaryDriver.licenseNumber, compact: true),
      _tableRow(_t('Tél.'), primaryDriver.phone, compact: true),
    ];

    if (secondaryDriver != null) {
      rows.addAll([
        _tableRow(_t('Cond. 2'), secondaryDriver.fullName, compact: true),
        _tableRow(_t('CIN 2'), secondaryDriver.cin, compact: true),
        _tableRow(_t('Permis 2'), secondaryDriver.licenseNumber, compact: true),
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(_t('Client')),
        pw.SizedBox(height: 2),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(2),
          },
          children: rows,
        ),
      ],
    );
  }

  pw.Widget _buildRentalSection(
    ContractModel contract,
    VehicleModel vehicle,
  ) {
    final start =
        _dateTimeFormatter.format(_standardizeTime(contract.startDate));
    final end = _dateTimeFormatter
        .format(_standardizeTime(contract.expectedReturnDate));
    final days = contract.rentalDays <= 0 ? 1 : contract.rentalDays;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(_t('Période & Tarifs')),
        pw.SizedBox(height: 2),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(2),
          },
          children: [
            _tableRow(_t('Début'), start, compact: true),
            _tableRow(_t('Fin'), end, compact: true),
            _tableRow(_t('Durée'), '$days ${_t('jours')}', compact: true),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: pw.EdgeInsets.all(6),
                  child: pw.Text(_t('Description'),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(6),
                  child: pw.Text(_t('Jours'),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(_t('Location'),
                      style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('$days ${_t('j')}',
                      style: const pw.TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPaymentSummary(ContractModel contract) {
    final remaining = contract.remainingAmount;
    final isFullyPaid = remaining <= 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(_t('Paiement')),
        pw.Text(
            '${_t('Total :')} ${contract.totalPrice.toStringAsFixed(2)} MAD | '
            '${_t('Versé :')} ${contract.amountPaid.toStringAsFixed(2)} MAD',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 12,
              height: 12,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black),
              ),
              child: isFullyPaid
                  ? pw.Center(
                      child: pw.Text(
                        'X',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    )
                  : null,
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              _t('Payé'),
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
            ),
            if (remaining > 0) ...[
              pw.SizedBox(width: 30),
              pw.Text(
                '${_t('Reste à payer :')} ${remaining.toStringAsFixed(2)} MAD',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  pw.Widget _buildCompanyAddressSection(String address) {
    if (address.isEmpty) return pw.SizedBox();
    return pw.Center(
      child: pw.Text(
        address,
        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTermsAndConditions() {
    return pw.Container(
      alignment: pw.Alignment.center,
      child: pw.Text(
        _t('Conditions: Le client accepte l’état du véhicule, les assurances, franchises et modalités de paiement.'),
        style: const pw.TextStyle(fontSize: 7),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildSignaturesSection(pw.MemoryImage? signatureImage) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _t('Signature Client'),
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Text(_t('Lu et accepté'),
                style: const pw.TextStyle(fontSize: 8)),
            pw.Signature(
              name: 'client_signature',
              child: pw.SizedBox(width: 230, height: 80),
            ),
            pw.Container(
              width: 230,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey),
                ),
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _t('Signature Agence'),
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 5),
            if (signatureImage != null)
              pw.Container(
                height: 35,
                child: pw.Image(signatureImage),
              )
            else
              pw.SizedBox(height: 35),
            pw.Container(
              width: 140,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromInt(0xFF1A237E),
      ),
    );
  }

  pw.TableRow _tableRow(String label, String value, {bool compact = false}) {
    final padding = compact ? 2.0 : 4.0;
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(padding),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(padding),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  String _t(String source) {
    final translated = AppLocalizations.translate(
      Locale(_languageCode),
      source,
    );
    if (translated != source) return translated;
    return switch (source) {
      'Notes :' => switch (_languageCode) {
          'en' => 'Notes:',
          'ar' => 'ملاحظات:',
          _ => source,
        },
      'CIN' => switch (_languageCode) {
          'en' => 'National ID',
          'ar' => 'بطاقة التعريف',
          _ => source,
        },
      'Permis' => switch (_languageCode) {
          'en' => 'Licence',
          'ar' => 'الرخصة',
          _ => source,
        },
      'Marque' => switch (_languageCode) {
          'en' => 'Brand',
          'ar' => 'العلامة',
          _ => source,
        },
      'Modèle' => switch (_languageCode) {
          'en' => 'Model',
          'ar' => 'الطراز',
          _ => source,
        },
      'Année' => switch (_languageCode) {
          'en' => 'Year',
          'ar' => 'السنة',
          _ => source,
        },
      'Nom' => switch (_languageCode) {
          'en' => 'Name',
          'ar' => 'الاسم',
          _ => source,
        },
      'Début' => switch (_languageCode) {
          'en' => 'Start',
          'ar' => 'البداية',
          _ => source,
        },
      'Durée' => switch (_languageCode) {
          'en' => 'Duration',
          'ar' => 'المدة',
          _ => source,
        },
      'Description' => switch (_languageCode) {
          'en' => 'Description',
          'ar' => 'الوصف',
          _ => source,
        },
      'Jours' => switch (_languageCode) {
          'en' => 'Days',
          'ar' => 'الأيام',
          _ => source,
        },
      'Location' => switch (_languageCode) {
          'en' => 'Rental',
          'ar' => 'التأجير',
          _ => source,
        },
      'Paiement' => switch (_languageCode) {
          'en' => 'Payment',
          'ar' => 'الدفع',
          _ => source,
        },
      'Reste à payer :' => switch (_languageCode) {
          'en' => 'Remaining:',
          'ar' => 'المتبقي للدفع:',
          _ => source,
        },
      'Contrat n°:' => switch (_languageCode) {
          'en' => 'Contract no.:',
          'ar' => 'رقم العقد:',
          _ => source,
        },
      'Location de véhicule' => switch (_languageCode) {
          'en' => 'Vehicle rental',
          'ar' => 'تأجير مركبة',
          _ => source,
        },
      'Date:' => switch (_languageCode) {
          'en' => 'Date:',
          'ar' => 'التاريخ:',
          _ => source,
        },
      'Immat.' => switch (_languageCode) {
          'en' => 'Plate',
          'ar' => 'التسجيل',
          _ => source,
        },
      'Tél.' => switch (_languageCode) {
          'en' => 'Phone',
          'ar' => 'الهاتف',
          _ => source,
        },
      'Cond. 2' => switch (_languageCode) {
          'en' => 'Driver 2',
          'ar' => 'السائق 2',
          _ => source,
        },
      'CIN 2' => switch (_languageCode) {
          'en' => 'National ID 2',
          'ar' => 'بطاقة التعريف 2',
          _ => source,
        },
      'Permis 2' => switch (_languageCode) {
          'en' => 'Licence 2',
          'ar' => 'الرخصة 2',
          _ => source,
        },
      'Période & Tarifs' => switch (_languageCode) {
          'en' => 'Period & rates',
          'ar' => 'الفترة والأسعار',
          _ => source,
        },
      'Fin' => switch (_languageCode) {
          'en' => 'End',
          'ar' => 'النهاية',
          _ => source,
        },
      'jours' => switch (_languageCode) {
          'en' => 'days',
          'ar' => 'أيام',
          _ => source,
        },
      'j' => switch (_languageCode) {
          'en' => 'd',
          'ar' => 'ي',
          _ => source,
        },
      'Total :' => switch (_languageCode) {
          'en' => 'Total:',
          'ar' => 'الإجمالي:',
          _ => source,
        },
      'Versé :' => switch (_languageCode) {
          'en' => 'Paid:',
          'ar' => 'المدفوع:',
          _ => source,
        },
      'Payé' => switch (_languageCode) {
          'en' => 'Paid',
          'ar' => 'مدفوع',
          _ => source,
        },
      'Signature Client' => switch (_languageCode) {
          'en' => 'Client signature',
          'ar' => 'توقيع العميل',
          _ => source,
        },
      'Lu et accepté' => switch (_languageCode) {
          'en' => 'Read and accepted',
          'ar' => 'تمت القراءة والموافقة',
          _ => source,
        },
      'Signature Agence' => switch (_languageCode) {
          'en' => 'Agency signature',
          'ar' => 'توقيع الوكالة',
          _ => source,
        },
      'Conditions: Le client accepte l’état du véhicule, les assurances, franchises et modalités de paiement.' =>
        switch (_languageCode) {
          'en' =>
            'Terms: The client accepts the vehicle condition, insurance, deductibles and payment terms.',
          'ar' =>
            'الشروط: يوافق العميل على حالة المركبة والتأمين والتحمل وشروط الدفع.',
          _ => source,
        },
      _ => source,
    };
  }

  Future<File> _getOutputFile(ContractModel contract) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeNumber =
        contract.contractNumber.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final filePath =
        p.join(dir.path, 'CarRent_Contracts', 'contract_$safeNumber.pdf');
    final fileDir = Directory(p.dirname(filePath));
    if (!await fileDir.exists()) {
      await fileDir.create(recursive: true);
    }
    return File(filePath);
  }
}
