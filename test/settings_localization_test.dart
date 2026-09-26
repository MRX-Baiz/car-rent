import 'dart:io';
import 'package:car_rent_manager/core/database/database_helper.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/core/constants/app_theme.dart';
import 'package:car_rent_manager/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    directory = await Directory.systemTemp.createTemp('carrent-localization-');
    await databaseFactory.setDatabasesPath(directory.path);
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.database;
  });
  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    await directory.delete(recursive:true);
  });
  for(final code in ['fr','en','ar']) {
    testWidgets('Settings uses selected language for company and reminders: $code', (tester) async {
      tester.view.physicalSize=const Size(390,844);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.reset);
      final messages=lookupAppMessages(Locale(code));
      await tester.pumpWidget(ProviderScope(child:MaterialApp(
        locale:Locale(code),theme:buildAppTheme(),supportedLocales:AppMessages.supportedLocales,
        localizationsDelegates:AppMessages.localizationsDelegates,
        home:const SettingsScreen(),
      )));
      for(var i=0;i<6;i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds:30)));
        await tester.pump(const Duration(milliseconds:100));
      }
      await tester.scrollUntilVisible(find.text(messages.companyInformation),200,scrollable:find.byType(Scrollable).first);
      await tester.tap(find.text(messages.companyInformation));
      await tester.pump(const Duration(milliseconds:400));
      await tester.scrollUntilVisible(find.text(messages.agencySignature),200,scrollable:find.byType(Scrollable).first);
      expect(find.text(messages.agencySignature),findsOneWidget);
      expect(find.text("Signature de l'agence"),findsNothing);
      expect(tester.takeException(),isNull);
      await tester.scrollUntilVisible(find.text(messages.scheduledReturnsLateVehiclesPayments),200,scrollable:find.byType(Scrollable).first);
      expect(find.text(messages.scheduledReturnsLateVehiclesPayments),findsOneWidget);
      await tester.scrollUntilVisible(find.text(messages.whenABalanceRemainsDueAtTheDeadline),200,scrollable:find.byType(Scrollable).first);
      expect(find.text(messages.whenABalanceRemainsDueAtTheDeadline),findsOneWidget);
      expect(tester.takeException(),isNull);
      expect(tester.widgetList<Text>(find.byType(Text)).map((t)=>t.data??'').where((t)=>t.startsWith('@')),isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
