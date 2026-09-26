import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/storage/media_store.dart';
import '../../../domain/entities/inspection.dart';

/// A lightweight vehicle image for inspection workflows.
///
/// It accepts the inspection entity rather than the SQLite vehicle model, so
/// the inspection form stays independent from persistence representation.
class InspectionVehiclePhoto extends StatelessWidget {
  const InspectionVehiclePhoto({
    super.key,
    required this.vehicle,
    this.borderRadius = 12,
    this.iconSize = 32,
  });

  final InspectionVehicle vehicle;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final file = vehicle.imageBytes == null
        ? MediaStore.instance.resolveFile(vehicle.imagePath)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: AppColors.primary.withValues(alpha: 0.08),
        child: SizedBox.expand(
          child: vehicle.imageBytes != null
              ? Image.memory(vehicle.imageBytes!, fit: BoxFit.cover)
              : file != null
                  ? Image.file(file, fit: BoxFit.cover)
                  : Icon(
                      Icons.directions_car_filled,
                      size: iconSize,
                      color: AppColors.primary,
                    ),
        ),
      ),
    );
  }
}
