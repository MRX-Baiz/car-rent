import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path/path.dart' as path_utils;
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/app_settings_repository.dart';
import 'assistant_models.dart';

/// Thin, local-only bridge to llama.cpp. The model file is selected by the
/// agency and is deliberately not shipped inside the APK.
class GemmaRuntimeService extends ChangeNotifier {
  GemmaRuntimeService._();

  static final GemmaRuntimeService instance = GemmaRuntimeService._();

  static const modelPathKey = 'assistant_local_gguf_path';
  LlamaController _controller = LlamaController();
  AssistantModelStatus _status = const AssistantModelStatus();

  AssistantModelStatus get status => _status;

  Future<void> restoreSelection() async {
    final path = await AppSettingsRepository.instance.getString(modelPathKey);
    if (path.isEmpty) return;
    _status = AssistantModelStatus(path: path);
    notifyListeners();
  }

  Future<void> setModelPath(String path) async {
    if (_status.isLoaded && _status.path != path) {
      await _resetController();
    }
    await AppSettingsRepository.instance.setString(modelPathKey, path);
    _status = AssistantModelStatus(path: path);
    notifyListeners();
  }

  /// Keeps a private app copy. Android's file chooser can return a temporary
  /// cache path, which would make the selected model disappear after a reboot.
  Future<void> importModelFile(String sourcePath) async {
    final previousPath = _status.path;
    final source = File(sourcePath);
    if (!sourcePath.toLowerCase().endsWith('.gguf') || !await source.exists()) {
      throw ArgumentError('Sélectionnez un fichier .gguf accessible.');
    }
    final documents = await getApplicationDocumentsDirectory();
    final models = Directory('${documents.path}/models');
    await models.create(recursive: true);
    // Keep the original filename. llama.cpp uses it to select the correct
    // chat template, such as Qwen's ChatML template.
    final target = File('${models.path}/${path_utils.basename(sourcePath)}');
    if (await target.exists() && target.absolute.path != source.absolute.path) {
      await target.delete();
    }
    if (target.absolute.path != source.absolute.path) {
      await source.copy(target.path);
    }
    await setModelPath(target.path);
    if (previousPath != null && previousPath != target.path) {
      await _deletePrivateModelCopy(previousPath);
    }
  }

  Future<void> clearModelPath() async {
    final previousPath = _status.path;
    if (_status.isLoaded) {
      await _resetController();
    }
    await AppSettingsRepository.instance.deleteString(modelPathKey);
    _status = const AssistantModelStatus();
    if (previousPath != null) {
      await _deletePrivateModelCopy(previousPath);
    }
    notifyListeners();
  }

  Future<void> loadSelectedModel() async {
    final path = _status.path;
    if (!Platform.isAndroid) {
      _setError('Le modèle local est disponible seulement sur Android.');
      return;
    }
    if (path == null || path.isEmpty) {
      _setError('Sélectionnez d’abord un fichier modèle .gguf.');
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      _setError(
          'Le fichier sélectionné est introuvable. Sélectionnez-le de nouveau.');
      return;
    }
    if (!path.toLowerCase().endsWith('.gguf')) {
      _setError('Le modèle doit être un fichier .gguf.');
      return;
    }
    _status = AssistantModelStatus(path: path, isLoading: true);
    notifyListeners();
    try {
      if (!await _controller.isModelLoaded()) {
        final gpu = await _controller.detectGpu();
        await _controller.loadModel(
          modelPath: path,
          threads: Platform.numberOfProcessors.clamp(2, 6),
          contextSize: 1024,
          gpuLayers: gpu.vulkanSupported ? gpu.recommendedGpuLayers : 0,
        );
      }
      _status = AssistantModelStatus(path: path, isLoaded: true);
    } catch (error) {
      _setError('Impossible de charger le modèle : $error', notify: false);
    }
    notifyListeners();
  }

  Future<String> improveAnswer({
    required String question,
    required String facts,
  }) async {
    if (!_status.isLoaded) return facts;
    await _controller.clearContext();
    final result = StringBuffer();
    final stream = _controller.generateChat(
      messages: [
        ChatMessage(
          role: 'system',
          content: 'Tu es l’assistant local d’une agence de location. '
              'Réponds en français simple, en 3 phrases maximum. '
              'Utilise uniquement les faits fournis. Si les faits ne répondent '
              'pas à la question, dis clairement que l’information est absente. '
              'Ne crée aucune donnée, ne donne aucune instruction dangereuse.',
        ),
        ChatMessage(
          role: 'user',
          content: 'Question : $question\n\nFaits de l’application :\n$facts',
        ),
      ],
      maxTokens: 180,
      temperature: 0.15,
      topP: 0.85,
    );
    await for (final token in stream) {
      result.write(token);
    }
    final answer = result.toString().trim();
    return answer.isEmpty ? facts : answer;
  }

  /// Answers general questions without agency data.
  Future<String> answerGeneralQuestion(String question) async {
    if (!_status.isLoaded) {
      throw StateError('Chargez le modèle avant de poser une question.');
    }
    await _controller.clearContext();
    final result = StringBuffer();
    final stream = _controller.generateChat(
      messages: [
        ChatMessage(
          role: 'system',
          content: 'Tu es un assistant utile. Réponds directement à la '
              'question dans la même langue que l’utilisateur. Sois court, '
              'clair et poli. Si tu ne connais pas la réponse, dis-le.',
        ),
        ChatMessage(role: 'user', content: question),
      ],
      maxTokens: 160,
      temperature: 0.35,
      topP: 0.9,
    );
    await for (final token in stream) {
      result.write(token);
    }
    final answer = result.toString().trim();
    return answer.isEmpty ? 'Le modèle n’a pas produit de réponse.' : answer;
  }

  void _setError(String message, {bool notify = true}) {
    _status = AssistantModelStatus(path: _status.path, error: message);
    if (notify) notifyListeners();
  }

  Future<void> _resetController() async {
    try {
      await _controller.dispose();
    } catch (_) {
      // The old native model may already be released after an interrupted run.
    }
    _controller = LlamaController();
  }

  Future<void> _deletePrivateModelCopy(String candidatePath) async {
    final documents = await getApplicationDocumentsDirectory();
    final modelsPrefix = '${documents.path}/models/';
    if (!candidatePath.startsWith(modelsPrefix)) return;
    final file = File(candidatePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
