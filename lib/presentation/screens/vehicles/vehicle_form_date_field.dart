import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';

class VehicleDateField extends StatelessWidget {
  const VehicleDateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          title: AppText(label),
          subtitle: AppText(value == null
              ? AppCopy.notProvidedd6a3c5
              : MaterialLocalizations.of(context).formatMediumDate(value!)),
          trailing: IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100));
                if (picked != null) onChanged(picked);
              }),
          onLongPress: value == null ? null : () => onChanged(null),
        ),
      );
}
