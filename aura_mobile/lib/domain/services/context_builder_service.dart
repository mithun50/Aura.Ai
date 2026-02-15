import 'package:aura_mobile/domain/services/document_service.dart';
import 'package:aura_mobile/domain/services/memory_service.dart';
import 'package:aura_mobile/domain/services/web_search_service.dart';
import 'package:aura_mobile/core/services/sms_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final contextBuilderServiceProvider =
    Provider((ref) => ContextBuilderService(
          ref.read(memoryServiceProvider),
          ref.read(documentServiceProvider),
          ref.read(webSearchServiceProvider),
          ref.read(smsServiceProvider),
        ));

class ContextBuilderService {
  final MemoryService _memoryService;
  final DocumentService _documentService;
  final WebSearchService _webSearchService;
  final SmsService _smsService;

  ContextBuilderService(
      this._memoryService, this._documentService, this._webSearchService, this._smsService);

  Future<String> buildPrompt({
    required String userMessage,
    required List<String> chatHistory,
    bool includeMemories = true,
    bool includeDocuments = true,
    bool includeWebSearch = false,
    bool includeSms = false,
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

    // 5. SMS Context
    if (includeSms) {
      try {
        final smsQuery = _extractSmsSearchQuery(userMessage);
        final messages = smsQuery.isNotEmpty
            ? await _smsService.searchMessages(smsQuery)
            : await _smsService.getRecentMessages(count: 10);
        if (messages.isNotEmpty) {
          buffer.writeln(_smsService.formatAsContext(messages));
        }
      } catch (_) {
        // SMS retrieval failed — continue
      }
    }

    // 6. Chat History
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

  /// Extract a meaningful search query from a raw user message about SMS.
  /// e.g. "show my messages from mom" → "mom"
  /// e.g. "texts from +1234567890" → "+1234567890"
  /// e.g. "read my recent messages" → "" (empty = get recent)
  String _extractSmsSearchQuery(String message) {
    final lower = message.toLowerCase().trim();

    // Patterns: "from <name>", "sms from <name>", "text from <name>", "messages from <name>"
    final fromPattern = RegExp(r'(?:from|by)\s+(.+?)(?:\s*[?.!]?\s*$)', caseSensitive: false);
    final fromMatch = fromPattern.firstMatch(lower);
    if (fromMatch != null) {
      return fromMatch.group(1)!.trim();
    }

    // Patterns: "about <topic>"
    final aboutPattern = RegExp(r'about\s+(.+?)(?:\s*[?.!]?\s*$)', caseSensitive: false);
    final aboutMatch = aboutPattern.firstMatch(lower);
    if (aboutMatch != null) {
      return aboutMatch.group(1)!.trim();
    }

    // Patterns: "with <name>"
    final withPattern = RegExp(r'with\s+(.+?)(?:\s*[?.!]?\s*$)', caseSensitive: false);
    final withMatch = withPattern.firstMatch(lower);
    if (withMatch != null) {
      return withMatch.group(1)!.trim();
    }

    // Phone number anywhere in message
    final phonePattern = RegExp(r'[\+]?[\d\s\-]{7,}');
    final phoneMatch = phonePattern.firstMatch(message);
    if (phoneMatch != null) {
      return phoneMatch.group(0)!.trim();
    }

    // If just asking for recent/all messages, return empty
    return '';
  }
}
