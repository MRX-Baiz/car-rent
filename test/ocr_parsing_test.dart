import 'package:flutter_test/flutter_test.dart';

import 'package:car_rent_manager/core/ocr/ocr_service.dart';

/// Parsing tests built from the layout of real Moroccan documents.
///
/// Only the Latin half of each card is modelled: every field the app needs
/// (names, numbers, dates, places) is printed in Latin script, so the Arabic
/// mirror carries no extra information.
void main() {
  final ocr = OcrService();

  group('CIN (Carte Nationale d\'Identité)', () {
    // Layout: given name first, surname second, both unlabelled.
    // Dates on the CIN use dots as separators.
    const cinText = '''
ROYAUME DU MAROC
CARTE NATIONALE D'IDENTITE
YASSINE
BENNANI
Né le 04.03.1985
à FES AGDAL FES
N° BK482916
Valable jusqu'au 21.09.2030
CAN 304518
''';

    test('extracts the CIN number', () {
      expect(ocr.parseCINData(cinText)['cin'], 'BK482916');
    });

    test('extracts birth and expiry dates (dot separators)', () {
      final r = ocr.parseCINData(cinText);
      expect(r['birthDate'], '04.03.1985');
      expect(r['expiryDate'], '21.09.2030');
    });

    test('given name precedes surname on the card', () {
      final r = ocr.parseCINData(cinText);
      expect(r['firstName'], 'YASSINE');
      expect(r['lastName'], 'BENNANI');
    });

    test('does not mistake the CAN serial for the CIN number', () {
      expect(ocr.parseCINData(cinText)['cin'], isNot(contains('304518')));
    });
  });

  group('Permis de Conduire', () {
    // Verbatim Apple Vision output for a real photo of this permis, including
    // its misreads. The 'Nom' label is missing because it is printed too small
    // to survive a phone photo, and the field labels do not sit next to their
    // values in reading order.
    const permisText = '''
ROYAUME DU MAROC
PERMIS DE CONDUIRE
Prénom /
Permis N° 12/345678
YOUSSEF AMINE
TAZI
Date et Lieu de naistance / 43P Je 1 0%
14/03/1990
SETTAT
delivré à Settat
Le
09/06/2019
B
N°C.N.LE 1.3.0, - ,
T482916
Diracteur de l'Agence Nationale
de la Ségurite Routière
higne: Benacew BOULAAJOUL
''';

    // A second photo of the same card, angled and blurrier. Here Vision drops
    // both name labels, so nothing anchors the names but the layout itself.
    const permisNoLabels = '''
ROYAUME DU MAROC
PERMIS DE CONDUIRE
Permis N° 12/345678 Las d
YOUSSEF AMINE
TAZI
Date et Li
14/03/1990
iS À
SETTAT
HA 2
delivre a Settat
''';

    test('extracts the permit number in XX/XXXXXX form', () {
      expect(ocr.parseLicenseData(permisText)['licenseNumber'], '12/345678');
    });

    // Observed on a real scan: both name fields came back empty because the
    // parser needed a label to anchor on and Vision had dropped 'Nom'.
    test('extracts names even though the Nom label was not recognised', () {
      final r = ocr.parseLicenseData(permisText);
      expect(r['firstName'], 'YOUSSEF AMINE');
      expect(r['lastName'], 'TAZI');
    });

    test('extracts names when no label at all was recognised', () {
      final r = ocr.parseLicenseData(permisNoLabels);
      expect(r['firstName'], 'YOUSSEF AMINE');
      expect(r['lastName'], 'TAZI');
    });

    test('does not mistake the birthplace for the surname', () {
      // SETTAT sits below the birth date, so structure separates it from
      // the names above.
      for (final text in [permisText, permisNoLabels]) {
        final r = ocr.parseLicenseData(text);
        expect(r['firstName'], isNot('SETTAT'));
        expect(r['lastName'], isNot('SETTAT'));
      }
    });

    test('permit number survives a blurry photo with trailing noise', () {
      expect(
        ocr.parseLicenseData(permisNoLabels)['licenseNumber'],
        '12/345678',
      );
    });

    test('reads the CIN printed under N.C.N.I.E.', () {
      expect(ocr.parseLicenseData(permisText)['cin'], 'T482916');
    });

    // Observed on a real scan: "03/1990" was lifted out of the birth date
    // 14/03/1990 and shown as the permit number.
    test('never mistakes part of a date for the permit number', () {
      final r = ocr.parseLicenseData(permisText);
      expect(r['licenseNumber'], isNot('03/1990'));
      expect(r['licenseNumber'], '12/345678');
    });

    test('permit number is found even when the date is recognised first', () {
      // Apple Vision does not guarantee reading order, so the date can precede
      // the permit number in the recognised text.
      const reordered = '''
Date et Lieu de naissance
14/03/1990
SETTAT
Permis N° 12/345678
''';
      expect(ocr.parseLicenseData(reordered)['licenseNumber'], '12/345678');
    });

    // The permis carries an issue date, not an expiry date. Treating the last
    // date on the card as the expiry flagged valid licences as expired.
    test('does not read the issue date as an expiry date', () {
      expect(ocr.parseLicenseData(permisText)['expiryDate'], isEmpty);
    });

    // Observed on Android: ML Kit groups text by position, not reading order,
    // so the 'Prénom' label landed next to the document title and the parser
    // filled Prénom with "PERMIS DE CONDUIRE" and Nom with the given name.
    test('pre-printed card wording is never taken as a name', () {
      const mlkitOrder = '''
ROYAUME DU MAROC
Prénom/
PERMIS DE CONDUIRE
YOUSSEF AMINE
Nom/
TAZI
14/03/1990
SETTAT
''';
      final r = ocr.parseLicenseData(mlkitOrder);
      expect(r['firstName'], 'YOUSSEF AMINE');
      expect(r['lastName'], 'TAZI');
      expect(r['firstName'], isNot(contains('PERMIS')));
    });

    test('the issuing authority is never taken as a name', () {
      const withFooter = '''
YOUSSEF AMINE
TAZI
14/03/1990
Directeur de l'Agence Nationale
DE LA SECURITE ROUTIERE
''';
      final r = ocr.parseLicenseData(withFooter);
      expect(r['firstName'], 'YOUSSEF AMINE');
      expect(r['lastName'], 'TAZI');
    });

    // "délivré à Settat / Le 09/06/2019" is the date of ISSUE. Reading it
    // as the expiry raised a false "permis expiré" warning on a valid licence.
    test('an issue date split across lines is not read as an expiry', () {
      const issueDate = '''
Permis N° 12/345678
YOUSSEF AMINE
TAZI
14/03/1990
SETTAT
délivré à Settat
Le
09/06/2019
''';
      expect(ocr.parseLicenseData(issueDate)['expiryDate'], isEmpty);
    });

    test('reads an expiry date when the card labels one', () {
      const withExpiry = '''
Permis N° 12/345678
Valable jusqu'au 09/06/2029
''';
      expect(
        ocr.parseLicenseData(withExpiry)['expiryDate'],
        '09/06/2029',
      );
    });
  });
}
