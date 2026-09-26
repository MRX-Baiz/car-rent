import '../../domain/repositories/contract_payment_repository.dart';
import 'contract_repository.dart';

/// SQLite-backed implementation of the atomic contract payment operation.
class SqliteContractPaymentRepository implements ContractPaymentRepository {
  SqliteContractPaymentRepository._internal();

  static final instance = SqliteContractPaymentRepository._internal();

  @override
  Future<void> recordPayment({
    required int contractId,
    required double amount,
  }) async {
    await ContractRepository.instance.addPaymentAndUpdateContract(
      contractId,
      amount,
    );
  }
}
