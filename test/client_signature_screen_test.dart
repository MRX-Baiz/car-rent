import 'package:car_rent_manager/presentation/screens/contracts/client_signature_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/french_app.dart';

void main() {
  testWidgets(
      'signature needs a stroke and clearing disables confirmation on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(frenchApp(
        home: const ClientSignatureScreen(clientName: 'Client Exemple')));
    final confirm = find.widgetWithText(FilledButton, 'Valider ma signature');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    final area = find.bySemanticsLabel('Zone de dessin de la signature');
    await tester.dragFrom(
        tester.getCenter(area) - const Offset(50, 0), const Offset(100, 20));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(find.text('Effacer et recommencer'));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
