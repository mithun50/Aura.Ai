import 'package:aura_mobile/domain/repositories/memory_repository.dart';
import 'package:aura_mobile/domain/entities/memory.dart';
import 'package:aura_mobile/domain/services/embedding_service.dart';
import 'package:aura_mobile/domain/services/date_time_parser.dart';
import 'package:aura_mobile/core/services/notification_service.dart';
import 'package:aura_mobile/core/providers/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final memoryServiceProvider = Provider((ref) => MemoryService(
      ref.read(memoryRepositoryProvider),
      ref.read(embeddingServiceProvider),
    ));

class MemoryService {
  final MemoryRepository _repository;
  final EmbeddingService _embeddingService;
  final DateTimeParser _dateTimeParser = DateTimeParser();
  final NotificationService _notificationService = NotificationService();

  MemoryService(this._repository, this._embeddingService);

  Future<void> saveMemory(String content) async {
    // 1. Parse date/time from content
    final parsedDateTime = _dateTimeParser.parse(content);
    final eventDate = parsedDateTime['date'] as DateTime?;
    final eventTime = parsedDateTime['time'];

    // 2. Generate Embedding using TF-IDF
    final embedding = _embeddingService.generateEmbedding(content);

    // 3. Create Memory entity
    final memory = Memory(
      id: const Uuid().v4(),
      content: content,
      category: 'general',
      timestamp: DateTime.now(),
      embedding: embedding,
      eventDate: eventDate,
      eventTime: eventTime,
      reminderScheduled: eventDate != null,
    );

    // 4. Save to DB
    await _repository.saveMemory(memory);

    // 5. Schedule notification if date exists
    if (eventDate != null) {
      await _notificationService.scheduleReminder(memory);
    }
  }

  Future<List<String>> retrieveRelevantMemories(String query,
      {int limit = 5}) async {
    // 1. Generate Query Embedding
    final queryEmbedding = _embeddingService.generateEmbedding(query);

    // 2. Fetch all memories
    final allMemories = await _repository.getMemories();

    // 3. Calculate Similarities
    final scoredMemories = allMemories.map((mem) {
      if (mem.embedding == null || mem.embedding!.isEmpty) {
        return MapEntry(mem, 0.0);
      }
      final score =
          _embeddingService.cosineSimilarity(queryEmbedding, mem.embedding!);
      return MapEntry(mem, score);
    }).toList();

    // 4. Sort and Top K
    scoredMemories.sort((a, b) => b.value.compareTo(a.value));

    return scoredMemories
        .take(limit)
        .where((entry) => entry.value > 0.15) // Lower threshold for TF-IDF
        .map((entry) => entry.key.content)
        .toList();
  }
}
