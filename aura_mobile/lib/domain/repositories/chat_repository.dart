import 'package:aura_mobile/domain/entities/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatMessage>> getMessages({int limit = 50});
  Future<void> saveMessage(ChatMessage message);
  Future<void> clearMessages();
}
