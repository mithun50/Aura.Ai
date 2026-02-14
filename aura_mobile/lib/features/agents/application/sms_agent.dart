import 'package:aura_mobile/data/datasources/llm_service.dart';
import 'package:aura_mobile/domain/services/context_builder_service.dart';
import 'package:aura_mobile/features/agents/domain/agent.dart';

class SmsAgent implements Agent {
  final LLMService _llmService;
  final ContextBuilderService _contextBuilder;

  SmsAgent(this._llmService, this._contextBuilder);

  @override
  String get name => 'SmsAgent';

  @override
  Future<bool> canHandle(String intent) async {
    return intent == 'sms_query';
  }

  @override
  Stream<String> process(
    String input, {
    Map<String, dynamic>? context,
    List<String> chatHistory = const [],
  }) async* {
    yield 'Reading your messages...';

    final fullPrompt = await _contextBuilder.buildPrompt(
      userMessage: input,
      chatHistory: chatHistory,
      includeMemories: false,
      includeDocuments: false,
      includeSms: true,
    );

    String fullResponse = '';
    final stream = _llmService.chat(input, systemPrompt: fullPrompt, maxTokens: 768);
    await for (final chunk in stream) {
      fullResponse += chunk;
      yield fullResponse;
    }

    if (fullResponse.isEmpty) {
      yield 'Could not read your messages. Please check SMS permissions.';
    }
  }
}
