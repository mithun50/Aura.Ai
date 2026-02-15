import 'package:aura_mobile/data/datasources/llm_service.dart';
import 'package:aura_mobile/domain/services/context_builder_service.dart';
import 'package:aura_mobile/features/agents/domain/agent.dart';

class ConversationAgent implements Agent {
  final LLMService _llmService;
  final ContextBuilderService _contextBuilder;

  ConversationAgent(this._llmService, this._contextBuilder);

  @override
  String get name => 'ConversationAgent';

  @override
  Future<bool> canHandle(String intent) async {
    return intent == 'normal_chat';
  }

  @override
  Stream<String> process(
    String input, {
    Map<String, dynamic>? context,
    List<String> chatHistory = const [],
  }) async* {
    if (!_llmService.isModelLoaded) {
      yield 'No model is loaded. Please go to Model Manager and select a model.';
      return;
    }

    final fullPrompt = await _contextBuilder.buildPrompt(
      userMessage: input,
      chatHistory: chatHistory,
      includeMemories: true,
      includeDocuments: true,
    );

    String accumulated = '';
    final stream = _llmService.chat(input, systemPrompt: fullPrompt);
    await for (final chunk in stream) {
      accumulated += chunk;
      yield accumulated;
    }

    if (accumulated.isEmpty) {
      yield 'I could not generate a response. Please check if a model is loaded.';
    }
  }
}
