import 'package:car_rent_manager/domain/repositories/contract_payment_repository.dart';
import 'package:car_rent_manager/domain/usecases/record_contract_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records a valid payment through the domain contract', () async {
    final repository = _FakeContractPaymentRepository();
    final recordPayment = RecordContractPayment(repository);

    await recordPayment(contractId: 12, amount: 250);

    expect(repository.recorded, equals((contractId: 12, amount: 250.0)));
  });

  test('rejects a zero or negative payment before reaching storage', () {
    final repository = _FakeContractPaymentRepository();
    final recordPayment = RecordContractPayment(repository);

    expect(
      () => recordPayment(contractId: 12, amount: 0),
      throwsArgumentError,
    );
    expect(repository.recorded, isNull);
  });
}

class _FakeContractPaymentRepository implements ContractPaymentRepository {
  ({int contractId, double amount})? recorded;

  @override
  Future<void> recordPayment({
    required int contractId,
    required double amount,
  }) async {
    recorded = (contractId: contractId, amount: amount);
  }
}
