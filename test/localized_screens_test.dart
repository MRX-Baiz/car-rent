import 'dart:async';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/core/constants/app_theme.dart';
import 'package:car_rent_manager/data/models/client_model.dart';
import 'package:car_rent_manager/data/models/contract_model.dart';
import 'package:car_rent_manager/data/models/vehicle_model.dart';
import 'package:car_rent_manager/presentation/providers/contract_provider.dart';
import 'package:car_rent_manager/presentation/providers/vehicle_provider.dart';
import 'package:car_rent_manager/presentation/providers/lookup_provider.dart';
import 'package:car_rent_manager/presentation/screens/dashboard/today_operations_screen.dart';
import 'package:car_rent_manager/presentation/widgets/contracts/contract_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Contracts extends ContractNotifier {
  _Contracts(this.items);
  final List<ContractModel> items;
  @override FutureOr<List<ContractModel>> build() => items;
}
class _Vehicles extends VehicleNotifier {
  _Vehicles(this.items);
  final List<VehicleModel> items;
  @override FutureOr<List<VehicleModel>> build() => items;
}
void main() {
  final now = DateTime.now();
  final car = VehicleModel(id: 1, brand: 'Bonjour', model: '2026', registrationNumber: 'AB-123', year: 2026, status: 'rented', createdAt: now, updatedAt: now);
  final client = ClientModel(id: 1, firstName: 'Paramètres', lastName: '', cin: 'AB123', licenseNumber: '12/345678', phone: '0600000000', createdAt: now, updatedAt: now);
  final contract = ContractModel(id: 1, contractNumber: 'CTR-ABC', vehicleId: 1, primaryDriverId: 1, startDate: now.subtract(const Duration(days: 2)), expectedReturnDate: now.subtract(const Duration(days: 1)), totalPrice: 300, amountPaid: 100, status: 'active', createdAt: now, updatedAt: now);
  final lookups = Lookups(vehicles: {1:car}, clients:{1:client});
  for (final code in ['fr','en','ar']) {
    testWidgets('contract card preserves entered data and translates badges in $code', (tester) async {
      tester.view.physicalSize = const Size(390,844);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(), locale: Locale(code),
        supportedLocales: AppMessages.supportedLocales,
        localizationsDelegates: AppMessages.localizationsDelegates,
        home: Scaffold(body: ContractCard(contract:contract,lookups:lookups)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Bonjour 2026'), findsOneWidget);
      expect(find.text(client.fullName), findsOneWidget);
      expect(find.text(AppLocalizations.translate(Locale(code), AppCopy.overdue)), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(Directionality.of(tester.element(find.byType(ContractCard))),code=='ar'?TextDirection.rtl:TextDirection.ltr);
      expect(tester.widgetList<Text>(find.byType(Text)).map((t)=>t.data??'').where((t)=>t.startsWith('@')), isEmpty);
    });
    testWidgets('today operations has localized labels and unchanged names in $code', (tester) async {
      tester.view.physicalSize = const Size(390,844);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.reset);
      final router = GoRouter(routes:[GoRoute(path:'/',builder:(_,__)=>const TodayOperationsScreen())]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(overrides:[
        contractsProvider.overrideWith(()=>_Contracts([contract])),
        vehiclesProvider.overrideWith(()=>_Vehicles([car])),
        lookupsProvider.overrideWith((_) async=>lookups),
      ],child:MaterialApp.router(theme:buildAppTheme(),locale:Locale(code),supportedLocales:AppMessages.supportedLocales,localizationsDelegates:AppMessages.localizationsDelegates,routerConfig:router)));
      await tester.pumpAndSettle();
      // AppPage shows the page title twice: once in the title block, once
      // (opacity-faded in from the app bar) once scrolled — the same
      // two-tier title Settings' hero already has.
      expect(find.text(AppLocalizations.translate(Locale(code),AppCopy.todaySOperations)), findsWidgets);
      expect(find.text('Bonjour 2026'), findsWidgets);
      expect(find.text(client.fullName), findsWidgets);
      expect(tester.takeException(),isNull);
      expect(tester.widgetList<Text>(find.byType(Text)).map((t)=>t.data??'').where((t)=>t.startsWith('@')), isEmpty);
    });
  }
}
