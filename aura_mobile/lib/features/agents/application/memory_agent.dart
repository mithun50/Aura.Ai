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
    if (input.toLowerCase().contains('save') ||
        input.toLowerCase().contains('remember') ||
        input.toLowerCase().contains('note that') ||
        input.toLowerCase().contains('memo:')) {
      final contentToSave = _extractMemoryContent(input);
      await _memoryService.saveMemory(contentToSave);
      yield "I've saved that to your memory.";
    } else {
      final memories = await _memoryService.retrieveRelevantMemories(input);
      if (memories.isEmpty) {
        yield "I couldn't find anything relevant in your memory.";
      } else {
        yield "Here's what I found:\n";
        for (final mem in memories) {
          yield "- $mem\n";
        }
      }
    }
  }

  String _extractMemoryContent(String message) {
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
}
