import 'package:aura_mobile/data/datasources/llm_service.dart';
import 'package:aura_mobile/domain/services/context_builder_service.dart';
import 'package:aura_mobile/features/agents/domain/agent.dart';

class RAGAgent implements Agent {
  final LLMService _llmService;
  final ContextBuilderService _contextBuilder;

  RAGAgent(this._llmService, this._contextBuilder);

  @override
  String get name => 'RAGAgent';

  @override
  Future<bool> canHandle(String intent) async {
    return intent == 'document_query' || intent == 'file_action';
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
      includeMemories: false,
      includeDocuments: true,
    );

    String accumulated = '';
    final stream = _llmService.chat(input, systemPrompt: fullPrompt, maxTokens: 768);
    await for (final chunk in stream) {
      accumulated += chunk;
      yield accumulated;
    }

    if (accumulated.isEmpty) {
      yield 'No relevant information found in your documents.';
    }
  }
}
