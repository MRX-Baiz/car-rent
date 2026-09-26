import '../entities/payment_record.dart';

/// Read-only payment history for a contract.
abstract interface class ContractPaymentHistoryRepository {
  Future<List<PaymentRecord>> listForContract(int contractId);
}
