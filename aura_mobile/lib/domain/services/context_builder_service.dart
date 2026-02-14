
import 'package:aura_mobile/domain/services/document_service.dart';
import 'package:aura_mobile/domain/services/memory_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final contextBuilderServiceProvider = Provider((ref) => ContextBuilderService(
  ref.read(memoryServiceProvider),
  ref.read(documentServiceProvider),
));

class ContextBuilderService {
  final MemoryService _memoryService;
  final DocumentService _documentService;

  ContextBuilderService(this._memoryService, this._documentService);

  Future<String> buildPrompt({
    required String userMessage,
    required List<String> chatHistory,
    bool includeMemories = true,
    bool includeDocuments = true,
  }) async {
    final buffer = StringBuffer();

    // 1. System Instruction
    buffer.writeln("SYSTEM INSTRUCTION:");
    buffer.writeln("You are AURA, a private offline AI assistant. Keep answers concise.");
    buffer.writeln("");

    // 2. Memory Context
    if (includeMemories) {
      final memories = await _memoryService.retrieveRelevantMemories(userMessage);
      if (memories.isNotEmpty) {
        buffer.writeln("MEMORY CONTEXT:");
        for (var mem in memories) {
          buffer.writeln("- $mem");
        }
        buffer.writeln("");
      }
    }

    // 3. Document Context
    if (includeDocuments) {
      final docContext = await _documentService.retrieveRelevantContext(userMessage);
      if (docContext.isNotEmpty) {
        buffer.writeln("DOCUMENT CONTEXT:");
        for (var chunk in docContext) {
          buffer.writeln(chunk);
        }
        buffer.writeln("");
      }
    }

    // 4. Chat History (limit to last 3 messages for performance)
    if (chatHistory.isNotEmpty) {
      final limitedHistory = chatHistory.length > 3 
          ? chatHistory.sublist(chatHistory.length - 3) 
          : chatHistory;
      
      buffer.writeln("CHAT HISTORY:");
      for (var msg in limitedHistory) {
        buffer.writeln(msg);
      }
      buffer.writeln("");
    }
    
    return buffer.toString();
  }
}
