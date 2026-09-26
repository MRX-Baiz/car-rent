import 'package:car_rent_manager/domain/entities/payment_record.dart';
import 'package:car_rent_manager/domain/repositories/contract_payment_history_repository.dart';
import 'package:car_rent_manager/domain/usecases/list_contract_payments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lists payment records through the domain history contract', () async {
    final useCase = ListContractPayments(_FakePaymentHistory());

    final payments = await useCase(8);

    expect(payments, hasLength(1));
    expect(payments.single.amount, 300);
    expect(payments.single.contractId, 8);
  });

  test('does not request history for an invalid contract', () {
    expect(
      () => ListContractPayments(_FakePaymentHistory())(0),
      throwsArgumentError,
    );
  });
}

class _FakePaymentHistory implements ContractPaymentHistoryRepository {
  @override
  Future<List<PaymentRecord>> listForContract(int contractId) async {
    return [
      PaymentRecord(
        id: 1,
        contractId: contractId,
        amount: 300,
        paidAt: DateTime(2026, 9, 26),
        method: 'cash',
      ),
    ];
  }
}
