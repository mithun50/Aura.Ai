import 'package:aura_mobile/features/agents/domain/agent.dart';
import 'package:aura_mobile/features/orchestrator/intent_classifier.dart';

class Orchestrator {
  final IntentClassifier _classifier;
  final List<Agent> _agents;

  Orchestrator(this._classifier, this._agents);

  Stream<String> processUserRequest(String input) async* {
    // 1. Classify Intent
    final intent = await _classifier.classify(input);
    
    // 2. Find Handling Agent
    Agent? selectedAgent;
    for (final agent in _agents) {
      if (await agent.canHandle(intent)) {
        selectedAgent = agent;
        break;
      }
    }

    if (selectedAgent == null) {
      // Fallback to conversation agent if specific one not found, or error
      // Assuming the last one is conversation or we have a default
      selectedAgent = _agents.firstWhere((a) => a.name == 'ConversationAgent', orElse: () => _agents.first);
    }

    // 3. Process
    yield* selectedAgent.process(input);
  }
}
