import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:car_rent_manager/presentation/widgets/common/app_button.dart';
import 'package:car_rent_manager/presentation/widgets/common/empty_state_widget.dart';
import 'package:car_rent_manager/presentation/widgets/common/status_badge.dart';
import 'helpers/french_app.dart';

void main() {
  testWidgets('Common widgets render', (WidgetTester tester) async {
    await tester.pumpWidget(
      frenchApp(
        home: const Scaffold(
          body: Column(
            children: [
              EmptyStateWidget(
                title: 'No data',
                subtitle: 'Add your first item',
              ),
              AppButton(
                label: 'Save',
                icon: Icons.save_outlined,
              ),
              StatusBadge(text: 'active'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('No data'), findsOneWidget);
    expect(find.text('Add your first item'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
  });
}
