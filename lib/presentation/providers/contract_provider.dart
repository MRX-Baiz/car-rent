import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/models/contract_model.dart';
import '../../data/repositories/contract_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/vehicle_repository.dart';

final contractsProvider =
    AsyncNotifierProvider<ContractNotifier, List<ContractModel>>(
  ContractNotifier.new,
);

class ContractNotifier extends AsyncNotifier<List<ContractModel>> {
  final ContractRepository _contractRepository = ContractRepository.instance;
  final PaymentRepository _paymentRepository = PaymentRepository.instance;
  final VehicleRepository _vehicleRepository = VehicleRepository.instance;

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
      await syncReminders(inserted);
      return [inserted, ...current];
    });
  }

  Future<void> updateContract(ContractModel contract) async {
    final current = state.value ?? const <ContractModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _contractRepository.updateContract(contract);
      // Moving the return date has to move the reminders with it.
      await syncReminders(contract);
      return current
          .map(
            (c) => c.id == contract.id ? contract : c,
          )
          .toList();
    });
  }

  /// Re-arms every reminder for [contract].
  ///
  /// Lives here rather than in the screens so no caller can add, edit, close
  /// or delete a contract and leave its reminders behind — which is how a
  /// deleted contract kept nagging about a vehicle that no longer existed.
  Future<void> syncReminders(ContractModel contract) async {
    final id = contract.id;
    if (id == null) return;

    if (contract.status != 'active') {
      await NotificationService.instance.cancelContractNotifications(id);
      return;
    }

    final vehicle = await _vehicleRepository.getVehicleById(contract.vehicleId);
    await NotificationService.instance.scheduleContractReminders(
      contractId: id,
      registrationNumber: vehicle?.registrationNumber ?? 'inconnu',
      startDate: contract.startDate,
      expectedReturnDate: contract.expectedReturnDate,
      remainingAmount: contract.remainingAmount,
    );
  }

  Future<void> closeContract(int id, DateTime returnDate) async {
    final current = state.value ?? const <ContractModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _contractRepository.closeContract(id, returnDate);
      await NotificationService.instance.cancelContractNotifications(id);
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

  Future<void> deleteContract(int id) async {
    final current = state.value ?? const <ContractModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _contractRepository.deleteContract(id);
      await NotificationService.instance.cancelContractNotifications(id);
      return current.where((c) => c.id != id).toList();
    });
  }

  Future<void> refreshPaymentsForContract(int contractId) async {
    final current = state.value ?? const <ContractModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Read the authoritative amount_paid from the contracts table (updated atomically by addPaymentAndUpdateContract)
      final freshContract = await _contractRepository.getContractById(contractId);
      return current
          .map(
            (c) => c.id == contractId && freshContract != null
                ? freshContract
                : c,
          )
          .toList();
    });
  }
}

