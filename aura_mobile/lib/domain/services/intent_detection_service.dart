
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum IntentType {
  normalChat,
  storeMemory,
  retrieveMemory,
  queryDocument,
}

final intentDetectionServiceProvider = Provider((ref) => IntentDetectionService());

class IntentDetectionService {
  IntentType detectIntent(String message, {bool hasDocuments = false}) {
    final lowerMessage = message.toLowerCase();

    // 1. Memory Store
    if (lowerMessage.startsWith("remember that") ||
        lowerMessage.startsWith("save this") ||
        lowerMessage.startsWith("note that")) {
      return IntentType.storeMemory;
    }

    // 2. Memory Retrieval
    if (lowerMessage.contains("when did i") ||
        lowerMessage.contains("what did i say") ||
        lowerMessage.contains("do you remember") ||
        lowerMessage.contains("remind me")) {
      return IntentType.retrieveMemory;
    }

    // 3. Document Query (Basic Heuristic)
    // If documents are loaded, we might default to RAG if the query looks like a question
    // For now, let's keep it simple: if hasDocuments is true and it's a question?
    if (hasDocuments && (lowerMessage.contains("?") || lowerMessage.contains("what") || lowerMessage.contains("summarize"))) {
        return IntentType.queryDocument;
    }

    // Default
    return IntentType.normalChat;
  }

  String extractMemoryContent(String message) {
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.startsWith("remember that")) {
      return message.substring("remember that".length).trim();
    }
    if (lowerMessage.startsWith("save this")) {
      return message.substring("save this".length).trim();
    }
    if (lowerMessage.startsWith("note that")) {
      return message.substring("note that".length).trim();
    }
    return message;
  }
}
