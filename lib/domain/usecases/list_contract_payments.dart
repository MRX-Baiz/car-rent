import '../entities/payment_record.dart';
import '../repositories/contract_payment_history_repository.dart';

class ListContractPayments {
  const ListContractPayments(this._repository);

  final ContractPaymentHistoryRepository _repository;

  Future<List<PaymentRecord>> call(int contractId) {
    if (contractId <= 0) throw ArgumentError.value(contractId, 'contractId');
    return _repository.listForContract(contractId);
  }
}
