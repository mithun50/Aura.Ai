import 'package:aura_mobile/features/agents/domain/agent.dart';
import 'package:aura_mobile/domain/services/memory_service.dart';

class MemoryAgent implements Agent {
  final MemoryService _memoryService;

  MemoryAgent(this._memoryService);

  @override
  String get name => 'MemoryAgent';

  @override
  Future<bool> canHandle(String intent) async {
    return intent == 'memory_store' || intent == 'memory_retrieve';
  }

  @override
  Stream<String> process(
    String input, {
    Map<String, dynamic>? context,
    List<String> chatHistory = const [],
  }) async* {
    final lowerInput = input.toLowerCase();

    if (lowerInput.startsWith('remember') ||
        lowerInput.startsWith('save') ||
        lowerInput.startsWith('note that') ||
        lowerInput.startsWith('memo:')) {
      try {
        final contentToSave = _extractMemoryContent(input);
        await _memoryService.saveMemory(contentToSave);
        yield "Got it! I've saved that to your memory.";
      } catch (e) {
        yield "Sorry, I couldn't save that memory. Please try again.";
      }
    } else {
      try {
        final memories = await _memoryService.retrieveRelevantMemories(input);
        if (memories.isEmpty) {
          yield "I don't have any relevant memories saved yet. You can save things by saying \"Remember that...\"";
        } else {
          final buffer = StringBuffer("Here's what I found in your memories:\n\n");
          for (final mem in memories) {
            buffer.writeln("- $mem");
          }
          yield buffer.toString();
        }
      } catch (e) {
        yield "Sorry, I had trouble searching your memories. Please try again.";
      }
    }
  }

  String _extractMemoryContent(String message) {
    final lowerMessage = message.toLowerCase();
    final prefixes = [
      'remember that ',
      'remember: ',
      'remember ',
      'save this: ',
      'save this ',
      'save: ',
      'save ',
      'note that ',
      'memo: ',
      'memo ',
    ];
    for (final prefix in prefixes) {
      if (lowerMessage.startsWith(prefix)) {
        return message.substring(prefix.length).trim();
      }
    }
    return message;
  }
}
