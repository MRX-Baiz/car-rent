class AssistantAction {
  final String label;
  final String route;

  const AssistantAction({required this.label, required this.route});
}

class AssistantAnswer {
  final String text;
  final List<AssistantAction> actions;
  final bool enhancedByModel;
  final bool allowDirectModel;

  const AssistantAnswer({
    required this.text,
    this.actions = const [],
    this.enhancedByModel = false,
    this.allowDirectModel = false,
  });
}

class AssistantModelStatus {
  final String? path;
  final bool isLoaded;
  final bool isLoading;
  final String? error;

  const AssistantModelStatus({
    this.path,
    this.isLoaded = false,
    this.isLoading = false,
    this.error,
  });

  bool get hasSelectedFile => path != null && path!.isNotEmpty;
}
