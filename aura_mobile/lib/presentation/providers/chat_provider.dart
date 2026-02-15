import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_mobile/core/services/voice_service.dart';
import 'package:aura_mobile/core/providers/ai_providers.dart';
import 'package:aura_mobile/domain/entities/chat_message.dart';
import 'package:aura_mobile/data/repositories/chat_repository_impl.dart';
import 'package:aura_mobile/domain/services/document_service.dart';

// Voice Service
final voiceServiceProvider = Provider((ref) => VoiceService());

// Chat State
class ChatState {
  final List<Map<String, String>> messages;
  final bool isListening;
  final bool isThinking;
  final bool isSpeaking;
  final int? speakingMessageIndex;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isThinking = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.speakingMessageIndex,
    this.error,
  });

  ChatState copyWith({
    List<Map<String, String>>? messages,
    bool? isThinking,
    bool? isListening,
    bool? isSpeaking,
    int? speakingMessageIndex,
    String? error,
  }) {
    final speaking = isSpeaking ?? this.isSpeaking;
    return ChatState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      isListening: isListening ?? this.isListening,
      isSpeaking: speaking,
      speakingMessageIndex: speaking ? (speakingMessageIndex ?? this.speakingMessageIndex) : null,
      error: error,
    );
  }
}

/// Special tokens to strip from displayed output
const _displayFilterTokens = [
  '<|im_start|>', '<|im_end|>', '<|endoftext|>', '</s>',
  '<|im_start|>assistant', '<|im_start|>user', '<|im_start|>system',
  '<s>', '<|begin_of_text|>', '<|end_of_text|>',
  '<|eot_id|>', '<|start_header_id|>', '<|end_header_id|>',
];

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

  /// Stop the current generation
  void stopGeneration() {
    if (_isProcessing) {
      try {
        final llmService = _ref.read(llmServiceProvider);
        llmService.stopGeneration();
      } catch (e) {
        if (kDebugMode) debugPrint('Error stopping generation: $e');
      }
    }
  }

  Future<void> sendMessage(String text) async {
    if (_isProcessing) return;
    _isProcessing = true;

    // Check if model is loaded
    final llmService = _ref.read(llmServiceProvider);
    if (!llmService.isModelLoaded) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          {'role': 'user', 'content': text},
          {'role': 'assistant', 'content': 'No model is loaded. Please go to Model Manager and select a model first.'},
        ],
      );
      await _saveMessage('user', text);
      await _saveMessage('assistant', 'No model is loaded. Please go to Model Manager and select a model first.');
      _isProcessing = false;
      return;
    }

    // 1. Add User Message
    state = state.copyWith(
      messages: [...state.messages, {'role': 'user', 'content': text}],
      isThinking: true,
      error: null,
    );

    // Persist user message
    await _saveMessage('user', text);

    // Placeholder for Assistant Response
    state = state.copyWith(
      messages: [...state.messages, {'role': 'assistant', 'content': ''}],
    );

    try {
      // Check if user has uploaded documents
      final documentService = _ref.read(documentServiceProvider);
      final hasDocuments = await documentService.hasDocuments();

      // Route everything through the Orchestrator
      final orchestrator = _ref.read(orchestratorProvider);
      final stream = orchestrator.processUserRequest(
        text,
        chatHistory: _recentHistory(),
        hasDocuments: hasDocuments,
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
      final errorMsg = 'Something went wrong. Please try again.';
      _updateLastMessage(errorMsg);
      await _saveMessage('assistant', errorMsg);
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

  /// Clean special tokens from the response
  String _cleanResponse(String text) {
    String cleaned = text;
    for (final token in _displayFilterTokens) {
      cleaned = cleaned.replaceAll(token, '');
    }
    // Also clean partial special tokens at the end (during streaming)
    cleaned = cleaned.replaceAll(RegExp(r'<\|[^>]*$'), '');
    return cleaned;
  }

  void _updateLastMessage(String rawContent) {
    final newMessages = List<Map<String, String>>.from(state.messages);
    if (newMessages.isNotEmpty && newMessages.last['role'] == 'assistant') {
      String thinking = '';
      String content = _cleanResponse(rawContent);
      String thinkingDone = 'false';

      // Parse <think>...</think> blocks
      final thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
      final match = thinkRegex.firstMatch(content);

      if (match != null) {
        thinking = match.group(1)?.trim() ?? '';
        content = content.replaceAll(thinkRegex, '').trim();
        thinkingDone = 'true';
      } else if (content.contains('<think>') &&
          !content.contains('</think>')) {
        final thinkStart = content.indexOf('<think>');
        thinking = content.substring(thinkStart + 7).trim();
        content = content.substring(0, thinkStart).trim();
        thinkingDone = 'false';
      }

      // Clean any remaining special tokens from content
      content = _cleanResponse(content);

      newMessages.last = {
        'role': 'assistant',
        'content': content,
        if (thinking.isNotEmpty) 'thinking': thinking,
        if (thinking.isNotEmpty) 'thinkingDone': thinkingDone,
      };
      state = state.copyWith(messages: newMessages);
    }
  }

  Future<void> speakMessage(String text, int messageIndex) async {
    final voiceService = _ref.read(voiceServiceProvider);
    await voiceService.initialize();
    state = state.copyWith(isSpeaking: true, speakingMessageIndex: messageIndex);
    await voiceService.speak(text);
    // TTS completion — reset state after speaking finishes
    // flutter_tts fires a completion handler internally, but we reset on next action
  }

  Future<void> stopSpeaking() async {
    final voiceService = _ref.read(voiceServiceProvider);
    await voiceService.stopSpeaking();
    state = state.copyWith(isSpeaking: false);
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
