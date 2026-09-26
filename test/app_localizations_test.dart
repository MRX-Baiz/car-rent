import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('translates core navigation labels into English and Arabic', () {
    expect(AppLocalizations.translate(const Locale('en'), 'Paramètres'),
        'Settings');
    expect(AppLocalizations.translate(const Locale('ar'), 'Paramètres'),
        'الإعدادات');
    expect(AppLocalizations.translate(const Locale('fr'), 'Paramètres'),
        'Paramètres');
  });

  test('keeps business data unchanged', () {
    expect(
        AppLocalizations.translate(const Locale('ar'), '123-A-45'), '123-A-45');
  });

  test('translates dashboard and settings copy, including live status text',
      () {
    const arabic = Locale('ar');
    expect(AppLocalizations.translate(arabic, 'Rappels de retour'),
        'تذكيرات الإرجاع');
    expect(AppLocalizations.translate(arabic, 'En retard de 20 h'),
        'متأخر بمقدار 20 ساعة');
    expect(
        AppLocalizations.translate(arabic, 'Reste 100 MAD'), 'المتبقي 100 MAD');
    expect(AppLocalizations.translate(arabic, 'Tous (2)'), 'الكل (2)');
    expect(AppLocalizations.translate(arabic, '2 véhicules · 0 disponible'),
        '2 مركبة · 0 متاحة');
    expect(AppLocalizations.translate(arabic, 'Bonsoir'), 'مساء الخير');
    expect(
      AppLocalizations.translate(
        arabic,
        'Le PDF sera préparé à la première ouverture.',
      ),
      'سيتم إعداد PDF عند فتحه للمرة الأولى.',
    );
  });

  testWidgets('Arabic text uses Arabic copy and right-to-left layout',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('fr'), Locale('en'), Locale('ar')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: AppText('Paramètres')),
      ),
    );

    expect(find.text('الإعدادات'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(AppText))),
        TextDirection.rtl);
  });
}
