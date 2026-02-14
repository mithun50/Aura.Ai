import 'package:aura_mobile/data/datasources/llm_service.dart';
import 'package:aura_mobile/domain/services/context_builder_service.dart';
import 'package:aura_mobile/domain/services/web_search_service.dart';
import 'package:aura_mobile/features/agents/domain/agent.dart';

class WebSearchAgent implements Agent {
  final LLMService _llmService;
  final WebSearchService _webSearchService;
  final ContextBuilderService _contextBuilder;

  WebSearchAgent(this._llmService, this._webSearchService, this._contextBuilder);

  @override
  String get name => 'WebSearchAgent';

  @override
  Future<bool> canHandle(String intent) async {
    return intent == 'web_search';
  }

  @override
  Stream<String> process(
    String input, {
    Map<String, dynamic>? context,
    List<String> chatHistory = const [],
  }) async* {
    yield 'Searching the web...';

    final searchQuery = _extractSearchQuery(input);
    final results = await _webSearchService.search(searchQuery, maxResults: 3);

    if (results.isEmpty) {
      yield 'No results found. You may be offline or the search failed.';
      return;
    }

    // Build base context WITHOUT web search (we already have results)
    final basePrompt = await _contextBuilder.buildPrompt(
      userMessage: input,
      chatHistory: chatHistory,
      includeMemories: false,
      includeDocuments: false,
      includeWebSearch: false,
    );

    // Append the already-fetched search results to avoid double search
    final searchContext = _webSearchService.formatResultsAsContext(results);
    final fullPrompt = '$basePrompt\n$searchContext';

    // Stream LLM response with search context
    String fullResponse = '';
    final stream = _llmService.chat(input, systemPrompt: fullPrompt, maxTokens: 768);
    await for (final chunk in stream) {
      fullResponse += chunk;
      yield fullResponse;
    }

    if (fullResponse.isEmpty) {
      // Fallback: show raw results if LLM didn't respond
      yield searchContext;
    }
  }

  String _extractSearchQuery(String message) {
    final lowerMessage = message.toLowerCase();
    final prefixes = [
      'search the web for',
      'search online for',
      'search for',
      'search:',
      'search ',
      'google ',
      'look up ',
      'find online ',
    ];
    for (final prefix in prefixes) {
      if (lowerMessage.startsWith(prefix)) {
        return message.substring(prefix.length).trim();
      }
    }
    return message;
  }
}
