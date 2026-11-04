import 'package:car_rent_manager/core/constants/app_colors.dart';
import 'package:car_rent_manager/core/utils/contract_insights.dart';
import 'package:car_rent_manager/core/utils/format_utils.dart';
import 'package:car_rent_manager/core/utils/vehicle_maintenance.dart';
import 'package:car_rent_manager/data/models/contract_model.dart';
import 'package:car_rent_manager/data/models/vehicle_model.dart';
import 'package:car_rent_manager/presentation/providers/lookup_provider.dart';
import 'package:car_rent_manager/presentation/widgets/common/alert_banner.dart';
import 'package:car_rent_manager/presentation/widgets/common/detail_row.dart';
import 'package:car_rent_manager/presentation/widgets/common/status_chip.dart';
import 'package:car_rent_manager/presentation/widgets/contracts/contract_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/french_app.dart';

final _now = DateTime(2026, 9, 20, 10);

VehicleModel _vehicle({
  DateTime? insurance,
  DateTime? oilDate,
  int? oilKm,
  int km = 50000,
}) =>
    VehicleModel(
      id: 1,
      brand: 'Dacia',
      model: 'Logan',
      registrationNumber: '12345-A-6',
      year: 2022,
      status: 'available',
      currentMileage: km,
      insuranceExpiryDate: insurance,
      oilChangeDueDate: oilDate,
      oilChangeDueMileage: oilKm,
      createdAt: _now,
      updatedAt: _now,
    );

ContractModel _contract({
  String status = 'active',
  required DateTime start,
  required DateTime end,
  double total = 1000,
  double paid = 0,
}) =>
    ContractModel(
      id: 1,
      contractNumber: 'CTR-1',
      vehicleId: 1,
      primaryDriverId: 1,
      startDate: start,
      expectedReturnDate: end,
      totalPrice: total,
      amountPaid: paid,
      status: status,
      createdAt: start,
      updatedAt: start,
    );

void main() {
  group('expiryOf', () {
    test('expired, today, soon and valid are told apart', () {
      expect(expiryOf(DateTime(2026, 9, 17), now: _now).tone, AppTone.danger);
      expect(expiryOf(DateTime(2026, 9, 17), now: _now).label,
          'Expiré depuis 3 j');
      expect(expiryOf(DateTime(2026, 9, 20), now: _now).label,
          'Expire aujourd’hui');
      expect(expiryOf(DateTime(2026, 10, 5), now: _now).tone, AppTone.warning);
      expect(expiryOf(DateTime(2027, 1, 1), now: _now).needsAttention, false);
    });

    test('a missing date is neutral, not an alert', () {
      final s = expiryOf(null, now: _now);
      expect(s.tone, AppTone.neutral);
      expect(s.needsAttention, false);
    });
  });

  group('maintenance', () {
    test('only lapsed or near items raise alerts, most urgent first', () {
      // Insurance in 11 days; oil change in 500 km, about 5 days of use.
      final v = _vehicle(
        insurance: DateTime(2026, 10, 1),
        oilKm: 50500,
      );
      final alerts = maintenanceAlerts(v, now: _now);
      expect(alerts.map((a) => a.label), ['Vidange', 'Assurance']);

      final lapsed = _vehicle(insurance: DateTime(2026, 9, 1), oilKm: 50500);
      expect(maintenanceAlerts(lapsed, now: _now).first.label, 'Assurance');
    });

    test('a service due by mileage and by date takes the worse of the two', () {
      final v = _vehicle(oilDate: DateTime(2027, 6, 1), oilKm: 49000);
      final oil = maintenanceItems(v, now: _now)
          .firstWhere((i) => i.label == 'Vidange');
      expect(oil.tone, AppTone.danger);
      expect(oil.needsAttention, true);
    });

    test('nothing set means nothing to report', () {
      expect(maintenanceAlerts(_vehicle(), now: _now), isEmpty);
    });
  });

  group('contract status', () {
    test('lateness is derived, never stored', () {
      final late = _contract(
        start: DateTime.now().subtract(const Duration(days: 5)),
        end: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(late.status, 'active');
      expect(late.displayStatus, 'late');

      final ok = _contract(
        start: DateTime.now(),
        end: DateTime.now().add(const Duration(days: 2)),
      );
      expect(ok.displayStatus, 'active');
    });

    test('return countdown wording', () {
      final c = _contract(
        start: DateTime(2026, 9, 18),
        end: DateTime(2026, 9, 22, 14),
      );
      expect(returnStatusOf(c, now: _now).label, 'Retour dans 2 j');
      expect(returnStatusOf(c, now: DateTime(2026, 9, 22, 8)).label,
          'Retour aujourd’hui à 14:00');
      expect(returnStatusOf(c, now: DateTime(2026, 9, 24, 14)).tone,
          AppTone.danger);
    });

    test('payment state', () {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 5);
      expect(
          paymentStatusOf(_contract(start: start, end: end, paid: 1000))
              .isSettled,
          true);
      expect(paymentStatusOf(_contract(start: start, end: end, paid: 400)).tone,
          AppTone.warning);
      expect(paymentStatusOf(_contract(start: start, end: end)).tone,
          AppTone.danger);
    });
  });

  test('formatMad groups thousands and hides empty cents', () {
    expect(formatMad(1250), '1 250 MAD');
    expect(formatMad(1250.5), '1 250,50 MAD');
  });

  group('small phone layout', () {
    Widget host(Widget child) => MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 640), textScaler: TextScaler.linear(1.5)),
          child: frenchApp(
            home: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        );

    testWidgets('chips, banners and detail rows do not overflow',
        (tester) async {
      await tester.pumpWidget(host(const Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          StatusChip(
              label: 'Assurance · Expiré depuis 128 jours',
              tone: AppTone.danger,
              icon: Icons.error_outline),
          AlertBanner(
            title: 'Notifications bloquées par Android',
            message: 'Aucun rappel ne s’affichera : ni retours, ni paiements.',
            actionLabel: 'Autoriser les notifications',
            tone: AppTone.danger,
          ),
          DetailRow(
            icon: Icons.person_outline,
            label: 'Conducteur principal',
            value: 'Mohamed El Amrani Alaoui',
            trailing: StatusChip(label: 'Permis · Valide'),
          ),
          MetricGrid(items: [
            MetricItem(Icons.speed_outlined, 'Kilométrage', '123 456 km'),
            MetricItem(Icons.settings_outlined, 'Boîte', 'Automatique'),
          ]),
        ]),
      )));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a late contract card fits and shows the return status',
        (tester) async {
      final c = _contract(
        start: DateTime.now().subtract(const Duration(days: 6)),
        end: DateTime.now().subtract(const Duration(days: 2)),
        paid: 200,
      );
      await tester.pumpWidget(host(Padding(
        padding: const EdgeInsets.all(16),
        child: ContractCard(contract: c, lookups: const Lookups()),
      )));
      expect(tester.takeException(), isNull);
      expect(find.text('En retard'), findsOneWidget);
      expect(find.textContaining('En retard de'), findsOneWidget);
    });
  });
}
