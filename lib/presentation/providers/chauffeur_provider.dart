import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/chauffeur_model.dart';
import '../../data/repositories/chauffeur_repository.dart';

final chauffeursProvider =
    AsyncNotifierProvider<ChauffeurNotifier, List<ChauffeurModel>>(
        ChauffeurNotifier.new);

class ChauffeurNotifier extends AsyncNotifier<List<ChauffeurModel>> {
  final _repo = ChauffeurRepository.instance;
  @override
  FutureOr<List<ChauffeurModel>> build() => _repo.all();
  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.all);
  }

  Future<void> save(ChauffeurModel value) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      if (value.id == null) {
        await _repo.insert(value.copyWith(createdAt: now, updatedAt: now));
      } else {
        await _repo.update(value.copyWith(updatedAt: now));
      }
      return _repo.all();
    });
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await load();
  }
}
