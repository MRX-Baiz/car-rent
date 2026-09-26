import 'package:flutter/material.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
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
     _ChatLine(
      text:
          AppCopy.helloISearchThisAgencySDataDirectly,
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
      final answer = await AssistantService.instance.answer(question, languageCode: Localizations.localeOf(context).languageCode);
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
      setState(() => _messages.add( _ChatLine(
            text: context.tr(AppCopy.iCouldNotReadTheDataTryAgain),
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
        title: const AppText(AppCopy.localAssistant),
        actions: [
          IconButton(
            tooltip: context.tr(AppCopy.configureLocalModel),
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
                    child: AppText(
                      status.isLoaded
                          ? context.messages.modelActive(context.tr(_modelLabel(status.path)))
                          : AppCopy.localQuickAnswersAddAGGUFModelTo,
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
                  _SuggestionChip(AppCopy.availableVehicles, _ask),
                  _SuggestionChip(AppCopy.overdueContracts, _ask),
                  _SuggestionChip(AppCopy.outstandingPayments, _ask),
                  _SuggestionChip(AppCopy.maintenanceAlerts, _ask),
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
                        alignment: AlignmentDirectional.centerStart,
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
                      decoration: InputDecoration(
                        hintText:
                            context.tr(AppCopy.eGWhichContractsAreOverdue),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: context.tr(AppCopy.send),
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
  if (path == null || path.isEmpty) return AppCopy.theLocalModel;
  final name = path.split('/').last;
  return name.length > 28 ? '${name.substring(0, 28)}…' : name;
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final Future<void> Function([String?]) onTap;

  const _SuggestionChip(this.text, this.onTap);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ActionChip(label: AppText(text), onPressed: () => onTap(context.tr(text))),
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
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
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
              isUser || message.model ? message.text : context.tr(message.text),
              style:
                  TextStyle(color: isUser ? theme.colorScheme.onPrimary : null),
            ),
            if (message.model) ...[
              const SizedBox(height: 6),
              AppText(AppCopy.writtenWithTheLocalModel,
                  style: theme.textTheme.labelSmall),
            ],
            for (final action in message.actions)
              TextButton.icon(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(top: 8)),
                onPressed: () => context.push(action.route),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: AppText(action.label),
              ),
          ],
        ),
      ),
    );
  }
}
