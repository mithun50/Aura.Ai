import 'package:flutter_riverpod/flutter_riverpod.dart';

enum IntentType {
  normalChat,
  storeMemory,
  retrieveMemory,
  queryDocument,
  webSearch,
}

final intentDetectionServiceProvider =
    Provider((ref) => IntentDetectionService());

class IntentDetectionService {
  IntentType detectIntent(String message, {bool hasDocuments = false}) {
    final lowerMessage = message.toLowerCase().trim();

    // 1. Memory Store
    if (lowerMessage.startsWith('remember that') ||
        lowerMessage.startsWith('save this') ||
        lowerMessage.startsWith('note that') ||
        lowerMessage.startsWith('remember:') ||
        lowerMessage.startsWith('memo:') ||
        lowerMessage.startsWith('save:')) {
      return IntentType.storeMemory;
    }

    // 2. Memory Retrieval
    if (lowerMessage.contains('when did i') ||
        lowerMessage.contains('what did i say') ||
        lowerMessage.contains('what did i save') ||
        lowerMessage.contains('do you remember') ||
        lowerMessage.contains('remind me') ||
        lowerMessage.contains('what do you know about me') ||
        lowerMessage.contains('my notes') ||
        lowerMessage.contains('my memories')) {
      return IntentType.retrieveMemory;
    }

    // 3. Web Search — explicit triggers
    if (lowerMessage.startsWith('search ') ||
        lowerMessage.startsWith('search:') ||
        lowerMessage.startsWith('google ') ||
        lowerMessage.startsWith('look up ') ||
        lowerMessage.startsWith('find online ') ||
        lowerMessage.contains('search the web') ||
        lowerMessage.contains('search online') ||
        lowerMessage.contains('latest news') ||
        lowerMessage.contains('current weather') ||
        lowerMessage.contains('what is happening')) {
      return IntentType.webSearch;
    }

    // 4. Document Query
    if (hasDocuments &&
        (lowerMessage.contains('in the document') ||
            lowerMessage.contains('in the pdf') ||
            lowerMessage.contains('from the file') ||
            lowerMessage.contains('summarize the') ||
            lowerMessage.contains('according to'))) {
      return IntentType.queryDocument;
    }

    // Default
    return IntentType.normalChat;
  }

  String extractMemoryContent(String message) {
    final lowerMessage = message.toLowerCase();
    final prefixes = [
      'remember that',
      'save this',
      'note that',
      'remember:',
      'memo:',
      'save:',
    ];
    for (final prefix in prefixes) {
      if (lowerMessage.startsWith(prefix)) {
        return message.substring(prefix.length).trim();
      }
    }
    return message;
  }

  /// Extract the search query from a web search intent message
  String extractSearchQuery(String message) {
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
