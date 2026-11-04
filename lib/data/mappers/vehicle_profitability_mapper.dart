import '../../domain/entities/vehicle_profitability.dart';
import '../models/contract_model.dart';

extension ContractProfitabilityMapper on ContractModel {
  ProfitabilityContract toProfitabilityContract() {
    return ProfitabilityContract(
      vehicleId: vehicleId,
      startDate: startDate,
      actualReturnDate: actualReturnDate,
      isActive: status == 'active',
      amountPaid: amountPaid,
    );
  }
}
