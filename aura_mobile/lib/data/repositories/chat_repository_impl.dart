import 'package:aura_mobile/data/datasources/database_helper.dart';
import 'package:aura_mobile/domain/entities/chat_message.dart';
import 'package:aura_mobile/domain/repositories/chat_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(DatabaseHelper());
});

class ChatRepositoryImpl implements ChatRepository {
  final DatabaseHelper _databaseHelper;

  ChatRepositoryImpl(this._databaseHelper);

  @override
  Future<List<ChatMessage>> getMessages({int limit = 50}) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    final db = await _databaseHelper.database;
    await db.insert('chat_messages', message.toMap());
  }

  @override
  Future<void> clearMessages() async {
    final db = await _databaseHelper.database;
    await db.delete('chat_messages');
  }
}
