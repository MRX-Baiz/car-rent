import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';

import '../../../core/assistant/gemma_runtime_service.dart';

class AssistantModelScreen extends StatefulWidget {
  const AssistantModelScreen({super.key});

  @override
  State<AssistantModelScreen> createState() => _AssistantModelScreenState();
}

class _AssistantModelScreenState extends State<AssistantModelScreen> {
  final _gemma = GemmaRuntimeService.instance;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _gemma.addListener(_refresh);
    _gemma.restoreSelection();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _gemma.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _selectFile() async {
    FilePickerResult? selection;
    try {
      // Some Android file managers ignore a custom `.gguf` MIME filter and
      // close without showing their picker. Open the normal document picker
      // instead, then check the extension ourselves below.
      selection = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
    } catch (error) {
      if (mounted) {
        _show(context.trError(error));
      }
      return;
    }
    final path = selection?.files.isNotEmpty == true
        ? selection!.files.first.path
        : null;
    if (path == null) return;
    if (!path.toLowerCase().endsWith('.gguf')) {
      _show(AppCopy.chooseAModelFileEndingInGguf);
      return;
    }
    if (!await File(path).exists()) {
      _show(AppCopy.theFileCannotBeAccessed);
      return;
    }
    setState(() => _working = true);
    try {
      await _gemma.importModelFile(path);
      if (mounted) {
        _show(
            AppCopy.modelFileCopiedIntoTheAppLoadIt);
      }
    } catch (error) {
      if (mounted) {
        _show(context.trError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _load() async {
    setState(() => _working = true);
    await _gemma.loadSelectedModel();
    if (!mounted) return;
    setState(() => _working = false);
    final error = _gemma.status.error;
    _show(error ?? 'Le modèle est prêt à être utilisé.');
  }

  void _show(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: AppText(text)));

  @override
  Widget build(BuildContext context) {
    final status = _gemma.status;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const AppText(AppCopy.offlineLocalModel)),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 32 + MediaQuery.viewPaddingOf(context).bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(AppCopy.localModel,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const AppText(
                            AppCopy.importAGGUFChatModelEachImportReplaces),
                        const SizedBox(height: 8),
                        const AppText(
                            AppCopy.theModelIsStoredSeparatelyFromTheApp),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Icon(
                        status.isLoaded
                            ? Icons.check_circle
                            : Icons.description_outlined,
                        color: status.isLoaded ? Colors.green : null),
                    title: AppText(status.isLoaded
                        ? AppCopy.modelLoaded
                        : AppCopy.noModelLoaded),
                    subtitle: AppText(status.path?.split('/').last ??
                        'Sélectionnez un fichier .gguf téléchargé sur le téléphone.'),
                  ),
                ),
                if (status.error != null) ...[
                  const SizedBox(height: 8),
                  AppText(context.trError(status.error!),
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _working ? null : _selectFile,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const AppText(AppCopy.selectGGUFFile),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _working || !status.hasSelectedFile ? null : _load,
                  icon: _working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.memory),
                  label: AppText(
                      status.isLoading ? AppCopy.loading : AppCopy.loadModel),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _working || !status.hasSelectedFile
                      ? null
                      : () => _gemma.clearModelPath(),
                  icon: const Icon(Icons.delete_outline),
                  label: const AppText(AppCopy.forgetThisFile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
