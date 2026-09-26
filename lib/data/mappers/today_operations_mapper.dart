import '../../domain/entities/today_operations.dart';
import '../models/contract_model.dart';
import '../models/vehicle_model.dart';

extension ContractOperationsMapper on ContractModel {
  OperationsContract? toOperationsContract() {
    final contractId = id;
    if (contractId == null) return null;
    return OperationsContract(
      id: contractId,
      vehicleId: vehicleId,
      clientId: primaryDriverId,
      startDate: startDate,
      expectedReturnDate: expectedReturnDate,
      remainingAmount: remainingAmount,
      isCompleted: status == 'completed',
    );
  }
}

extension VehicleOperationsMapper on VehicleModel {
  OperationsVehicle? toOperationsVehicle() {
    final vehicleId = id;
    if (vehicleId == null) return null;
    return OperationsVehicle(
      id: vehicleId,
      isBlockedForMaintenance: status == 'maintenance',
      documents: [
        VehicleDocumentDeadline(
          type: VehicleDocumentType.insurance,
          dueDate: insuranceExpiryDate,
        ),
        VehicleDocumentDeadline(
          type: VehicleDocumentType.technicalInspection,
          dueDate: technicalInspectionExpiryDate,
        ),
        VehicleDocumentDeadline(
          type: VehicleDocumentType.roadTax,
          dueDate: vignetteDueDate,
        ),
      ],
    );
  }
}
