import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/client_model.dart';
import '../../data/repositories/client_repository.dart';

final clientsProvider =
    AsyncNotifierProvider<ClientNotifier, List<ClientModel>>(
  ClientNotifier.new,
);

class ClientNotifier extends AsyncNotifier<List<ClientModel>> {
  final ClientRepository _repository = ClientRepository.instance;

  @override
  FutureOr<List<ClientModel>> build() async {
    return _repository.getAllClients();
  }

  Future<void> loadClients() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.getAllClients);
  }

  Future<void> addClient(ClientModel client) async {
    final current = state.value ?? const <ClientModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final toInsert = client.copyWith(
        createdAt: client.createdAt,
        updatedAt: now,
      );
      final id = await _repository.insertClient(toInsert);
      final inserted = toInsert.copyWith(id: id);
      return [inserted, ...current];
    });
    // Propagate errors so the form can catch them and show the right message.
    if (state is AsyncError) {
      final err = (state as AsyncError).error;
      throw err is Exception ? err : Exception(err.toString());
    }
  }

  Future<void> updateClient(ClientModel client) async {
    final current = state.value ?? const <ClientModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updated = client.copyWith(updatedAt: DateTime.now());
      await _repository.updateClient(updated);
      return current
          .map(
            (c) => c.id == updated.id ? updated : c,
          )
          .toList();
    });
    // Propagate errors so the form can catch them and show the right message.
    if (state is AsyncError) {
      final err = (state as AsyncError).error;
      // Restore previous list so the UI isn't stuck on an error state.
      state = AsyncValue.data(current);
      throw err is Exception ? err : Exception(err.toString());
    }
  }

  Future<void> deleteClient(int id) async {
    final current = state.value ?? const <ClientModel>[];
    // Keep current list visible; update only on success.
    try {
      await _repository.deleteClient(id);
      state = AsyncValue.data(current.where((c) => c.id != id).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.searchClients(query));
  }
}

