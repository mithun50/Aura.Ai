import 'package:flutter/foundation.dart';
import 'package:aura_mobile/features/agents/domain/agent.dart';
import 'package:aura_mobile/features/orchestrator/intent_classifier.dart';

class Orchestrator {
  final IntentClassifier _classifier;
  final List<Agent> _agents;

  Orchestrator(this._classifier, this._agents);

  Stream<String> processUserRequest(
    String input, {
    List<String> chatHistory = const [],
    bool hasDocuments = false,
  }) async* {
    try {
      // 1. Classify Intent
      final intent = await _classifier.classify(input, hasDocuments: hasDocuments);
      if (kDebugMode) debugPrint('Orchestrator: intent=$intent');

      // 2. Find Handling Agent
      Agent? selectedAgent;
      for (final agent in _agents) {
        if (await agent.canHandle(intent)) {
          selectedAgent = agent;
          break;
        }
      }

      // Fallback to ConversationAgent
      selectedAgent ??= _agents
          .where((a) => a.name == 'ConversationAgent')
          .firstOrNull ?? _agents.first;

      if (kDebugMode) debugPrint('Orchestrator: agent=${selectedAgent.name}');

      // 3. Process with chat history
      yield* selectedAgent.process(input, chatHistory: chatHistory);
    } catch (e) {
      if (kDebugMode) debugPrint('Orchestrator error: $e');
      yield 'Error: $e';
    }
  }
}
