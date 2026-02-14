import 'package:aura_mobile/domain/services/document_service.dart';
import 'package:aura_mobile/domain/services/memory_service.dart';
import 'package:aura_mobile/domain/services/web_search_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final contextBuilderServiceProvider =
    Provider((ref) => ContextBuilderService(
          ref.read(memoryServiceProvider),
          ref.read(documentServiceProvider),
          ref.read(webSearchServiceProvider),
        ));

class ContextBuilderService {
  final MemoryService _memoryService;
  final DocumentService _documentService;
  final WebSearchService _webSearchService;

  ContextBuilderService(
      this._memoryService, this._documentService, this._webSearchService);

  Future<String> buildPrompt({
    required String userMessage,
    required List<String> chatHistory,
    bool includeMemories = true,
    bool includeDocuments = true,
    bool includeWebSearch = false,
  }) async {
    final buffer = StringBuffer();

    // 1. System Instruction
    buffer.writeln('SYSTEM INSTRUCTION:');
    buffer.writeln(
        'You are AURA, a private AI assistant. Keep answers concise and helpful.');
    buffer.writeln(
        'If web search results are provided, use them to give accurate, up-to-date answers.');
    buffer.writeln(
        'If memory context is provided, use it to personalize your response.');
    buffer.writeln('');

    // 2. Web Search Context
    if (includeWebSearch) {
      try {
        final searchQuery = userMessage;
        final results = await _webSearchService.search(searchQuery);
        if (results.isNotEmpty) {
          buffer.writeln(_webSearchService.formatResultsAsContext(results));
        }
      } catch (_) {
        // Web search failed silently — continue without it
      }
    }

    // 3. Memory Context
    if (includeMemories) {
      try {
        final memories =
            await _memoryService.retrieveRelevantMemories(userMessage);
        if (memories.isNotEmpty) {
          buffer.writeln('MEMORY CONTEXT:');
          for (var mem in memories) {
            buffer.writeln('- $mem');
          }
          buffer.writeln('');
        }
      } catch (_) {
        // Memory retrieval failed — continue
      }
    }

    // 4. Document Context
    if (includeDocuments) {
      try {
        final docContext =
            await _documentService.retrieveRelevantContext(userMessage);
        if (docContext.isNotEmpty) {
          buffer.writeln('DOCUMENT CONTEXT:');
          for (var chunk in docContext) {
            buffer.writeln(chunk);
          }
          buffer.writeln('');
        }
      } catch (_) {
        // Document retrieval failed — continue
      }
    }

    // 5. Chat History
    if (chatHistory.isNotEmpty) {
      final limitedHistory = chatHistory.length > 4
          ? chatHistory.sublist(chatHistory.length - 4)
          : chatHistory;

      buffer.writeln('CHAT HISTORY:');
      for (var msg in limitedHistory) {
        buffer.writeln(msg);
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }
}
