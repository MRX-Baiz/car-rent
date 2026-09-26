/// Atomic payment operation owned by the contract aggregate.
///
/// Recording a payment must also update the contract balance in the same
/// transaction, so it is intentionally separate from generic payment storage.
abstract interface class ContractPaymentRepository {
  Future<void> recordPayment({
    required int contractId,
    required double amount,
  });
}
