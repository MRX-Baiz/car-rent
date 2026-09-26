import '../../domain/entities/payment_record.dart';
import '../../domain/repositories/contract_payment_history_repository.dart';
import '../models/payment_model.dart';
import 'payment_repository.dart';

/// SQLite adapter for payment history.
class SqliteContractPaymentHistoryRepository
    implements ContractPaymentHistoryRepository {
  SqliteContractPaymentHistoryRepository._internal();

  static final instance = SqliteContractPaymentHistoryRepository._internal();

  @override
  Future<List<PaymentRecord>> listForContract(int contractId) async {
    final payments =
        await PaymentRepository.instance.getPaymentsByContractId(contractId);
    return payments.map(_toEntity).toList(growable: false);
  }

  static PaymentRecord _toEntity(PaymentModel payment) {
    return PaymentRecord(
      id: payment.id,
      contractId: payment.contractId,
      amount: payment.amount,
      paidAt: payment.paymentDate,
      method: payment.paymentMethod,
      note: payment.notes,
    );
  }
}
