import 'package:aura_mobile/domain/entities/memory.dart';

abstract class MemoryRepository {
  Future<List<Memory>> getMemories();
  Future<void> saveMemory(Memory memory);
  Future<List<Memory>> searchMemories(String query);
  Future<void> deleteMemory(String id);
}
