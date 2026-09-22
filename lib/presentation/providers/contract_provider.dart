import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/models/contract_model.dart';
import '../../data/repositories/contract_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import 'chauffeur_provider.dart';
import 'vehicle_provider.dart';

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
    // Without this, a failed edit (frozen terms, a vehicle already booked
    // elsewhere...) looked like a success: AsyncValue.guard swallows the
    // error into `state` rather than throwing, so the editing screen's own
    // try/catch never ran.
    if (state is AsyncError) {
      final err = (state as AsyncError).error;
      state = AsyncValue.data(current);
      throw err is Exception ? err : Exception(err.toString());
    }
    // Reassigning the vehicle/chauffeur on an active contract flips their
    // status in the database; refresh the lists that cache it separately, or
    // the vehicles/chauffeurs screens keep showing the old assignment.
    await _refreshRelated();
  }

  Future<void> restoreReminders() async {
    final contracts = await _contractRepository.getAllContracts();
    for (final contract in contracts) {
      await syncReminders(contract, requestPermissions: false);
    }
  }

  /// Re-arms every reminder for [contract].
  ///
  /// Lives here rather than in the screens so no caller can add, edit, close
  /// or delete a contract and leave its reminders behind — which is how a
  /// deleted contract kept nagging about a vehicle that no longer existed.
  Future<void> syncReminders(ContractModel contract,
      {bool requestPermissions = true}) async {
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
      requestPermissions: requestPermissions,
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
    if (state is AsyncError) {
      final err = (state as AsyncError).error;
      state = AsyncValue.data(current);
      throw err is Exception ? err : Exception(err.toString());
    }
    await _refreshRelated();
  }

  Future<void> deleteContract(int id) async {
    final current = state.value ?? const <ContractModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _contractRepository.deleteContract(id);
      await NotificationService.instance.cancelContractNotifications(id);
      return current.where((c) => c.id != id).toList();
    });
    if (state is AsyncError) {
      final err = (state as AsyncError).error;
      state = AsyncValue.data(current);
      throw err is Exception ? err : Exception(err.toString());
    }
    await _refreshRelated();
  }

  /// Vehicles and chauffeurs are cached in their own providers; a contract
  /// mutation that the repository is known to flip their status for (create,
  /// edit, close, delete) has to pull those caches back in sync.
  Future<void> _refreshRelated() async {
    await ref.read(vehiclesProvider.notifier).loadVehicles();
    await ref.read(chauffeursProvider.notifier).load();
  }

  Future<void> refreshPaymentsForContract(int contractId) async {
    final current = state.value ?? const <ContractModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Read the authoritative amount_paid from the contracts table (updated atomically by addPaymentAndUpdateContract)
      final freshContract =
          await _contractRepository.getContractById(contractId);
      return current
          .map(
            (c) =>
                c.id == contractId && freshContract != null ? freshContract : c,
          )
          .toList();
    });
  }
}
