import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/contract_model.dart';
import '../../data/repositories/contract_repository.dart';
import '../../data/repositories/payment_repository.dart';

final contractsProvider =
    AsyncNotifierProvider<ContractNotifier, List<ContractModel>>(
  ContractNotifier.new,
);

class ContractNotifier extends AsyncNotifier<List<ContractModel>> {
  final ContractRepository _contractRepository = ContractRepository.instance;
  final PaymentRepository _paymentRepository = PaymentRepository.instance;

  @override
  FutureOr<List<ContractModel>> build() async {
    return _contractRepository.getAllContracts();
  }

  Future<void> loadContracts() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_contractRepository.getAllContracts);
  }

  Future<void> addContract(ContractModel contract) async {
    final current = state.value ?? const <ContractModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final id = await _contractRepository.insertContract(contract);
      final inserted = contract.copyWith(id: id);
      return [inserted, ...current];
    });
  }

  Future<void> updateContract(ContractModel contract) async {
    final current = state.value ?? const <ContractModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _contractRepository.updateContract(contract);
      return current
          .map(
            (c) => c.id == contract.id ? contract : c,
          )
          .toList();
    });
  }

  Future<void> closeContract(int id, DateTime returnDate) async {
    final current = state.value ?? const <ContractModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _contractRepository.closeContract(id, returnDate);
      return current
          .map(
            (c) => c.id == id
                ? c.copyWith(
                    status: 'completed',
                    actualReturnDate: returnDate,
                    updatedAt: DateTime.now(),
                  )
                : c,
          )
          .toList();
    });
  }

  Future<void> refreshPaymentsForContract(int contractId) async {
    final current = state.value ?? const <ContractModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final totalPaid =
          await _paymentRepository.getTotalPaidForContract(contractId);
      return current
          .map(
            (c) => c.id == contractId
                ? c.copyWith(
                    amountPaid: totalPaid,
                    updatedAt: DateTime.now(),
                  )
                : c,
          )
          .toList();
    });
  }
}

