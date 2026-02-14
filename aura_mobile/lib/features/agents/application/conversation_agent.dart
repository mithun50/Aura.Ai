import 'package:aura_mobile/data/datasources/llm_service.dart';
import 'package:aura_mobile/features/agents/domain/agent.dart';

class ConversationAgent implements Agent {
  final LLMService _llmService;

  ConversationAgent(this._llmService);

  @override
  String get name => 'ConversationAgent';

  @override
  Future<bool> canHandle(String intent) async {
    return intent == 'normal_chat';
  }

  @override
  Stream<String> process(String input, {Map<String, dynamic>? context}) {
    String systemPrompt =
        'You are AURA, a private offline AI assistant. Prioritize user memory and privacy.';

    if (context != null && context.containsKey('memory')) {
      systemPrompt += "\n\nRelevant personal memory:\n${context['memory']}";
    }

    return _llmService.chat(input, systemPrompt: systemPrompt);
  }
}
