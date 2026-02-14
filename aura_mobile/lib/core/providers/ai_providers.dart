import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_mobile/ai/run_anywhere_service.dart';
import 'package:aura_mobile/data/datasources/llm_service.dart';
import 'package:aura_mobile/domain/services/context_builder_service.dart';
import 'package:aura_mobile/domain/services/memory_service.dart';
import 'package:aura_mobile/domain/services/web_search_service.dart';
import 'package:aura_mobile/features/agents/application/conversation_agent.dart';
import 'package:aura_mobile/features/agents/application/memory_agent.dart';
import 'package:aura_mobile/features/agents/application/rag_agent.dart';
import 'package:aura_mobile/features/agents/application/web_search_agent.dart';
import 'package:aura_mobile/features/agents/application/sms_agent.dart';
import 'package:aura_mobile/features/orchestrator/orchestrator.dart';
import 'package:aura_mobile/features/orchestrator/intent_classifier.dart';

// Core AI Services
final runAnywhereProvider = Provider((ref) => RunAnywhere());
final llmServiceProvider = Provider((ref) => LLMServiceImpl(ref.watch(runAnywhereProvider)));

// Intent Classifier
final intentClassifierProvider = Provider((ref) => IntentClassifier());

// Orchestrator with all agents wired up
final orchestratorProvider = Provider((ref) {
  final llmService = ref.read(llmServiceProvider);
  final contextBuilder = ref.read(contextBuilderServiceProvider);
  final memoryService = ref.read(memoryServiceProvider);
  final webSearchService = ref.read(webSearchServiceProvider);
  final classifier = ref.read(intentClassifierProvider);

  return Orchestrator(
    classifier,
    [
      ConversationAgent(llmService, contextBuilder),
      MemoryAgent(memoryService),
      RAGAgent(llmService, contextBuilder),
      WebSearchAgent(llmService, webSearchService, contextBuilder),
      SmsAgent(llmService, contextBuilder),
    ],
  );
});
