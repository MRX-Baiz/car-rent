import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/contract_payment_history_repository.dart';
import '../../data/repositories/contract_payment_repository.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/repositories/contract_payment_history_repository.dart';
import '../../domain/repositories/contract_payment_repository.dart';
import '../../domain/usecases/list_contract_payments.dart';
import '../../domain/usecases/record_contract_payment.dart';

final contractPaymentRepositoryProvider =
    Provider<ContractPaymentRepository>((ref) {
  return SqliteContractPaymentRepository.instance;
});

final recordContractPaymentProvider = Provider<RecordContractPayment>((ref) {
  return RecordContractPayment(ref.watch(contractPaymentRepositoryProvider));
});

final contractPaymentHistoryRepositoryProvider =
    Provider<ContractPaymentHistoryRepository>((ref) {
  return SqliteContractPaymentHistoryRepository.instance;
});

final listContractPaymentsProvider = Provider<ListContractPayments>((ref) {
  return ListContractPayments(
      ref.watch(contractPaymentHistoryRepositoryProvider));
});

final contractPaymentHistoryProvider = FutureProvider.autoDispose
    .family<List<PaymentRecord>, int>((ref, contractId) {
  return ref.watch(listContractPaymentsProvider)(contractId);
});
