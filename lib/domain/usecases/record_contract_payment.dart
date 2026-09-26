import '../repositories/contract_payment_repository.dart';

class RecordContractPayment {
  const RecordContractPayment(this._repository);

  final ContractPaymentRepository _repository;

  Future<void> call({required int contractId, required double amount}) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be greater than zero');
    }
    return _repository.recordPayment(contractId: contractId, amount: amount);
  }
}
