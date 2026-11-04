import '../../domain/entities/client_history.dart';
import '../models/contract_model.dart';

extension ContractClientHistoryMapper on ContractModel {
  ClientRentalRecord? toClientRentalRecord({required bool hadDamage}) {
    final contractId = id;
    if (contractId == null) return null;
    return ClientRentalRecord(
      contractId: contractId,
      startDate: startDate,
      expectedReturnDate: expectedReturnDate,
      actualReturnDate: actualReturnDate,
      isActive: status == 'active',
      remainingAmount: remainingAmount,
      hadDamage: hadDamage,
    );
  }
}
