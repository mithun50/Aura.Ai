import 'package:aura_mobile/features/agents/domain/agent.dart';
import 'package:aura_mobile/domain/repositories/memory_repository.dart';
import 'package:aura_mobile/domain/entities/memory.dart';
import 'package:uuid/uuid.dart';

class MemoryAgent implements Agent {
  final MemoryRepository _memoryRepository;

  MemoryAgent(this._memoryRepository);

  @override
  String get name => 'MemoryAgent';

  @override
  Future<bool> canHandle(String intent) async {
    return intent == 'memory_store' || intent == 'memory_retrieve';
  }

  @override
  Stream<String> process(String input, {Map<String, dynamic>? context}) async* {
    if (input.toLowerCase().contains('save') ||
        input.toLowerCase().contains('remember')) {
      final memory = Memory(
        id: const Uuid().v4(),
        content: input,
        category: 'general',
        timestamp: DateTime.now(),
      );
      await _memoryRepository.saveMemory(memory);
      yield "I've saved that to your memory.";
    } else {
      final memories = await _memoryRepository.searchMemories(input);
      if (memories.isEmpty) {
        yield "I couldn't find anything relevant in your memory.";
      } else {
        yield "Here's what I found:\n";
        for (final mem in memories) {
          yield "- ${mem.content}\n";
        }
      }
    }
  }
}
