import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_mobile/core/services/voice_service.dart';
import 'package:aura_mobile/core/providers/ai_providers.dart';
import 'package:aura_mobile/domain/entities/chat_message.dart';
import 'package:aura_mobile/data/repositories/chat_repository_impl.dart';

// Voice Service
final voiceServiceProvider = Provider((ref) => VoiceService());

// Chat State
class ChatState {
  final List<Map<String, String>> messages;
  final bool isListening;
  final bool isThinking;

  ChatState({
    this.messages = const [],
    this.isThinking = false,
    this.isListening = false,
  });

  ChatState copyWith({
    List<Map<String, String>>? messages,
    bool? isThinking,
    bool? isListening,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      isListening: isListening ?? this.isListening,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  bool _isProcessing = false;

  ChatNotifier(this._ref) : super(ChatState()) {
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    try {
      state = state.copyWith(isThinking: true);

      // Load persisted chat history
      await _loadMessages();

      final llmService = _ref.read(llmServiceProvider);
      await llmService.initialize();
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing AI: $e');
    } finally {
      state = state.copyWith(isThinking: false);
    }
  }

  Future<void> _loadMessages() async {
    try {
      final repo = _ref.read(chatRepositoryProvider);
      final messages = await repo.getMessages(limit: 50);
      if (messages.isNotEmpty) {
        state = state.copyWith(
          messages: messages.map((m) => m.toChatMap()).toList(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading chat history: $e');
    }
  }

  Future<void> _saveMessage(String role, String content, {String? thinking}) async {
    try {
      final repo = _ref.read(chatRepositoryProvider);
      await repo.saveMessage(ChatMessage(
        role: role,
        content: content,
        thinking: thinking,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving message: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (_isProcessing) return;
    _isProcessing = true;

    // 1. Add User Message
    state = state.copyWith(
      messages: [...state.messages, {'role': 'user', 'content': text}],
      isThinking: true,
    );

    // Persist user message
    await _saveMessage('user', text);

    // Placeholder for Assistant Response
    state = state.copyWith(
      messages: [...state.messages, {'role': 'assistant', 'content': ''}],
    );

    try {
      // Route everything through the Orchestrator
      final orchestrator = _ref.read(orchestratorProvider);
      final stream = orchestrator.processUserRequest(
        text,
        chatHistory: _recentHistory(),
        hasDocuments: true,
      );

      String fullResponse = '';
      await for (final chunk in stream) {
        fullResponse = chunk;
        _updateLastMessage(fullResponse);
      }

      if (fullResponse.isEmpty) {
        fullResponse =
            'I could not generate a response. Please check if a model is loaded.';
        _updateLastMessage(fullResponse);
      }

      // Persist assistant message
      final lastMsg = state.messages.last;
      await _saveMessage(
        'assistant',
        lastMsg['content'] ?? fullResponse,
        thinking: lastMsg['thinking'],
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error in sendMessage: $e');
      _updateLastMessage('Error: $e');
      await _saveMessage('assistant', 'Error: $e');
    } finally {
      state = state.copyWith(isThinking: false);
      _isProcessing = false;
    }
  }

  List<String> _recentHistory() {
    return state.messages
        .where((m) =>
            (m['role'] == 'user' || m['role'] == 'assistant') &&
            (m['content']?.isNotEmpty ?? false))
        .map((m) =>
            "${m['role'] == 'user' ? 'User' : 'Assistant'}: ${m['content']}")
        .toList()
        .reversed
        .take(4)
        .toList()
        .reversed
        .toList();
  }

  void _updateLastMessage(String rawContent) {
    final newMessages = List<Map<String, String>>.from(state.messages);
    if (newMessages.isNotEmpty && newMessages.last['role'] == 'assistant') {
      String thinking = '';
      String content = rawContent;
      String thinkingDone = 'false';

      // Parse <think>...</think> blocks
      final thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
      final match = thinkRegex.firstMatch(rawContent);

      if (match != null) {
        thinking = match.group(1)?.trim() ?? '';
        content = rawContent.replaceAll(thinkRegex, '').trim();
        thinkingDone = 'true';
      } else if (rawContent.contains('<think>') &&
          !rawContent.contains('</think>')) {
        final thinkStart = rawContent.indexOf('<think>');
        thinking = rawContent.substring(thinkStart + 7).trim();
        content = rawContent.substring(0, thinkStart).trim();
        thinkingDone = 'false';
      }

      newMessages.last = {
        'role': 'assistant',
        'content': content,
        if (thinking.isNotEmpty) 'thinking': thinking,
        if (thinking.isNotEmpty) 'thinkingDone': thinkingDone,
      };
      state = state.copyWith(messages: newMessages);
    }
  }

  Future<void> clearChat() async {
    try {
      final repo = _ref.read(chatRepositoryProvider);
      await repo.clearMessages();
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing chat history: $e');
    }
    state = state.copyWith(messages: []);
  }

  Future<void> stopListening() async {
    final voiceService = _ref.read(voiceServiceProvider);
    await voiceService.stopListening();
    state = state.copyWith(isListening: false);
  }

  Future<void> startListening() async {
    final voiceService = _ref.read(voiceServiceProvider);
    await voiceService.initialize();
    state = state.copyWith(isListening: true);

    await voiceService.startListening(onResult: (text) {
      if (text.isNotEmpty) {
        state = state.copyWith(isListening: false);
        sendMessage(text);
        stopListening();
      }
    });
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
