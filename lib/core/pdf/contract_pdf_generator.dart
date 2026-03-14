import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/client_model.dart';
import '../../data/models/contract_model.dart';
import '../../data/models/vehicle_model.dart';

class ContractPdfGenerator {
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  Future<File> generateContract({
    required ContractModel contract,
    required VehicleModel vehicle,
    required ClientModel primaryDriver,
    ClientModel? secondaryDriver,
  }) async {
    final doc = pw.Document();

    final creationDate = contract.createdAt;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.openSansRegular(),
            bold: await PdfGoogleFonts.openSansBold(),
          ),
        ),
        build: (context) => [
          _buildHeader(contract, creationDate),
          pw.SizedBox(height: 16),
          _buildVehicleSection(vehicle),
          pw.SizedBox(height: 16),
          _buildClientSection(primaryDriver, secondaryDriver),
          pw.SizedBox(height: 16),
          _buildRentalSection(contract, vehicle),
          pw.SizedBox(height: 16),
          _buildPaymentSummary(contract),
          pw.SizedBox(height: 24),
          _buildTermsAndConditions(),
          pw.SizedBox(height: 32),
          _buildSignaturesSection(),
        ],
      ),
    );

    final output = await _getOutputFile(contract);
    final bytes = await doc.save();
    await output.writeAsBytes(bytes, flush: true);
    return output;
  }

  Future<void> shareContract(File pdfFile) async {
    await Share.shareXFiles(
      [XFile(pdfFile.path)],
      text: 'Contrat de location de véhicule',
    );
  }

  Future<void> printContract(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
    );
  }

  pw.Widget _buildHeader(ContractModel contract, DateTime creationDate) {
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
                pw.Text(
                  'CarRent Manager',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF1A237E),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Contrat de location de véhicule',
                  style: pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
            pw.Container(
              width: 80,
              height: 40,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'LOGO',
                style: pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Contrat n°: ${contract.contractNumber}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
            ),
            pw.Text(
              'Date: ${_dateFormatter.format(creationDate)}',
              style: pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildVehicleSection(VehicleModel vehicle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Détails du véhicule'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(2),
          },
          children: [
            _tableRow('Marque', vehicle.brand),
            _tableRow('Modèle', vehicle.model),
            _tableRow('Immatriculation', vehicle.registrationNumber),
            _tableRow('Année', vehicle.year.toString()),
            _tableRow('Tarif journalier', '${vehicle.dailyPrice.toStringAsFixed(2)} MAD'),
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
      _tableRow('Nom complet', primaryDriver.fullName),
      _tableRow('CIN', primaryDriver.cin),
      _tableRow('Permis', primaryDriver.licenseNumber),
      _tableRow('Adresse', primaryDriver.address ?? '-'),
      _tableRow('Téléphone', primaryDriver.phone),
      _tableRow('Email', primaryDriver.email ?? '-'),
    ];

    if (secondaryDriver != null) {
      rows.addAll([
        _tableRow('Second conducteur', secondaryDriver.fullName),
        _tableRow('CIN (2ème)', secondaryDriver.cin),
        _tableRow('Permis (2ème)', secondaryDriver.licenseNumber),
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Détails du ou des client(s)'),
        pw.SizedBox(height: 8),
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
    final start = _dateFormatter.format(contract.startDate);
    final end = _dateFormatter.format(contract.expectedReturnDate);
    final days = contract.rentalDays <= 0 ? 1 : contract.rentalDays;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Période et tarification'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths:  {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(2),
          },
          children: [
            _tableRow('Date de début', start),
            _tableRow('Date de retour prévue', end),
            _tableRow('Nombre de jours', days.toString()),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children:  [
                pw.Padding(
                  padding: pw.EdgeInsets.all(6),
                  child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(6),
                  child: pw.Text('Jours', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(6),
                  child:
                      pw.Text('Tarif / jour', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(6),
                  child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                 pw.Padding(
                  padding: pw.EdgeInsets.all(6),
                  child: pw.Text('Location véhicule'),
                ),
                pw.Padding(
                  padding:  pw.EdgeInsets.all(6),
                  child: pw.Text(days.toString()),
                ),
                pw.Padding(
                  padding:  pw.EdgeInsets.all(6),
                  child: pw.Text('${vehicle.dailyPrice.toStringAsFixed(2)} MAD'),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(6),
                  child: pw.Text('${contract.totalPrice.toStringAsFixed(2)} MAD'),
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

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Récapitulatif des paiements'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths:  {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(1),
          },
          children: [
            _tableRow('Total contrat', '${contract.totalPrice.toStringAsFixed(2)} MAD'),
            _tableRow('Montant payé', '${contract.amountPaid.toStringAsFixed(2)} MAD'),
            _tableRow('Reste à payer', '${remaining.toStringAsFixed(2)} MAD'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTermsAndConditions() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Conditions générales'),
        pw.SizedBox(height: 8),
        pw.Text(
          'Ce contrat est établi entre l’agence de location de véhicules et le(s) client(s) '
          'désigné(s) ci-dessus. Le client reconnaît avoir pris connaissance et accepter les '
          'conditions générales de location de véhicules de l’agence, notamment en ce qui '
          'concerne :\n'
          '- L’état du véhicule et l’usage qui en est fait.\n'
          '- Les assurances et franchises applicables.\n'
          '- Les modalités de paiement, les dépôts de garantie et les pénalités de retard.\n'
          '- Les règles de conduite, d’entretien et de restitution du véhicule.\n\n'
          'Les conditions complètes sont disponibles à l’agence et peuvent être annexées à '
          'ce contrat selon les besoins de l’entreprise.',
          style: pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  pw.Widget _buildSignaturesSection() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Signature du client',
              style:  pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              width: 180,
              decoration:  pw.BoxDecoration(
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
              'Signature de l’agent',
              style:  pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              width: 180,
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
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromInt(0xFF1A237E),
      ),
    );
  }

  pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding:  pw.EdgeInsets.all(6),
          child: pw.Text(
            label,
            style:  pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(6),
          child: pw.Text(value),
        ),
      ],
    );
  }

  Future<File> _getOutputFile(ContractModel contract) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeNumber = contract.contractNumber.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final filePath = p.join(dir.path, 'contracts', 'contract_$safeNumber.pdf');
    final fileDir = Directory(p.dirname(filePath));
    if (!await fileDir.exists()) {
      await fileDir.create(recursive: true);
    }
    return File(filePath);
  }
}

