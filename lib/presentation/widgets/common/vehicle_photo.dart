import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/storage/media_store.dart';
import '../../../data/models/vehicle_model.dart';

/// The vehicle's photo, or a neutral car icon when it has none (or the stored
/// file is gone). Sizing is the caller's job: wrap it in a SizedBox/AspectRatio.
class VehiclePhoto extends StatelessWidget {
  const VehiclePhoto({
    super.key,
    required this.vehicle,
    this.borderRadius = 12,
    this.iconSize = 32,
  });

  final VehicleModel vehicle;
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
                  : Icon(Icons.directions_car_filled,
                      size: iconSize, color: AppColors.primary),
        ),
      ),
    );
  }
}
