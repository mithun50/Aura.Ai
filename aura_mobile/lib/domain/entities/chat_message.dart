class ChatMessage {
  final int? id;
  final String role;
  final String content;
  final String? thinking;
  final DateTime timestamp;

  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.thinking,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'role': role,
      'content': content,
      'thinking': thinking,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      role: map['role'] as String,
      content: map['content'] as String,
      thinking: map['thinking'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  /// Convert to the Map<String, String> format used by ChatState
  Map<String, String> toChatMap() {
    return {
      'role': role,
      'content': content,
      if (thinking != null && thinking!.isNotEmpty) 'thinking': thinking!,
      if (thinking != null && thinking!.isNotEmpty) 'thinkingDone': 'true',
    };
  }

  factory ChatMessage.fromChatMap(Map<String, String> map) {
    return ChatMessage(
      role: map['role'] ?? 'user',
      content: map['content'] ?? '',
      thinking: map['thinking'],
      timestamp: DateTime.now(),
    );
  }
}
