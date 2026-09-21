import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assistant/assistant_models.dart';
import '../../../core/assistant/assistant_service.dart';
import '../../../core/assistant/gemma_runtime_service.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _messages = <_ChatLine>[
    const _ChatLine(
      text:
          'Bonjour. Je cherche dans les données de cette agence, directement sur ce téléphone.',
      isUser: false,
    ),
  ];
  final _gemma = GemmaRuntimeService.instance;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    AssistantService.instance.refreshAgencyData();
    _gemma.addListener(_refresh);
    _gemma.restoreSelection();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _gemma.removeListener(_refresh);
    _input.dispose();
    super.dispose();
  }

  Future<void> _ask([String? suggestion]) async {
    final question = (suggestion ?? _input.text).trim();
    if (question.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _sending = true;
      _messages.add(_ChatLine(text: question, isUser: true));
    });
    try {
      final answer = await AssistantService.instance.answer(question);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatLine(
          text: answer.text,
          isUser: false,
          actions: answer.actions,
          model: answer.enhancedByModel,
        ));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _messages.add(const _ChatLine(
            text: 'Je n’ai pas pu lire les données. Réessayez dans un instant.',
            isUser: false,
          )));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _gemma.status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant local'),
        actions: [
          IconButton(
            tooltip: 'Configurer le modèle local',
            icon: const Icon(Icons.memory_outlined),
            onPressed: () => context.push('/assistant/model'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status.isLoaded
                    ? Colors.green.withValues(alpha: .10)
                    : theme.colorScheme.primaryContainer.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(status.isLoaded ? Icons.memory : Icons.storage_outlined,
                      color: status.isLoaded
                          ? Colors.green
                          : theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status.isLoaded
                          ? '${_modelLabel(status.path)} est actif. Les données affichées restent celles de l’agence.'
                          : 'Réponses rapides locales. Ajoutez un modèle GGUF pour discuter hors ligne.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  _SuggestionChip('Véhicules disponibles', _ask),
                  _SuggestionChip('Contrats en retard', _ask),
                  _SuggestionChip('Paiements en attente', _ask),
                  _SuggestionChip('Alertes entretien', _ask),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    );
                  }
                  final message = _messages[index];
                  return _MessageBubble(message: message);
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                12 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask(),
                      decoration: const InputDecoration(
                        hintText: 'Ex. Quels contrats sont en retard ?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Envoyer',
                    onPressed: _sending ? null : _ask,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _modelLabel(String? path) {
  if (path == null || path.isEmpty) return 'Le modèle local';
  final name = path.split('/').last;
  return name.length > 28 ? '${name.substring(0, 28)}…' : name;
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final Future<void> Function([String?]) onTap;

  const _SuggestionChip(this.text, this.onTap);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(label: Text(text), onPressed: () => onTap(text)),
      );
}

class _ChatLine {
  final String text;
  final bool isUser;
  final List<AssistantAction> actions;
  final bool model;

  const _ChatLine({
    required this.text,
    required this.isUser,
    this.actions = const [],
    this.model = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatLine message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style:
                  TextStyle(color: isUser ? theme.colorScheme.onPrimary : null),
            ),
            if (message.model) ...[
              const SizedBox(height: 6),
              Text('Rédigé avec le modèle local',
                  style: theme.textTheme.labelSmall),
            ],
            for (final action in message.actions)
              TextButton.icon(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(top: 8)),
                onPressed: () => context.push(action.route),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(action.label),
              ),
          ],
        ),
      ),
    );
  }
}
