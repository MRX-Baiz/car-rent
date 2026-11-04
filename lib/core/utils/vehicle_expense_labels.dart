import 'package:flutter/material.dart';

import '../../domain/entities/vehicle_expense.dart';
import '../localization/app_localizations.dart';

String expenseCategoryLabel(VehicleExpenseCategory category) => switch (category) {
      VehicleExpenseCategory.repair => AppCopy.expenseCategoryRepair,
      VehicleExpenseCategory.insurance => AppCopy.expenseCategoryInsurance,
      VehicleExpenseCategory.fine => AppCopy.expenseCategoryFine,
      VehicleExpenseCategory.other => AppCopy.expenseCategoryOther,
    };

IconData expenseCategoryIcon(VehicleExpenseCategory category) => switch (category) {
      VehicleExpenseCategory.repair => Icons.build_outlined,
      VehicleExpenseCategory.insurance => Icons.shield_outlined,
      VehicleExpenseCategory.fine => Icons.gavel_outlined,
      VehicleExpenseCategory.other => Icons.receipt_long_outlined,
    };
