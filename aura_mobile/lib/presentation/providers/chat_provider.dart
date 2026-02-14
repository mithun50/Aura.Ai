import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_mobile/domain/services/intent_detection_service.dart';
import 'package:aura_mobile/domain/services/memory_service.dart';
import 'package:aura_mobile/domain/services/context_builder_service.dart';
import 'package:aura_mobile/domain/services/web_search_service.dart';
import 'package:aura_mobile/core/services/voice_service.dart';
import 'package:aura_mobile/core/providers/ai_providers.dart';

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
      final llmService = _ref.read(llmServiceProvider);
      await llmService.initialize();
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing AI: $e');
    } finally {
      state = state.copyWith(isThinking: false);
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

    // Placeholder for Assistant Response
    state = state.copyWith(
      messages: [...state.messages, {'role': 'assistant', 'content': ''}],
    );

    try {
      final intentService = _ref.read(intentDetectionServiceProvider);
      final memoryService = _ref.read(memoryServiceProvider);
      final contextBuilder = _ref.read(contextBuilderServiceProvider);
      final llmService = _ref.read(llmServiceProvider);
      final webSearchService = _ref.read(webSearchServiceProvider);

      // 2. Detect Intent
      final intent = intentService.detectIntent(text, hasDocuments: true);

      if (intent == IntentType.storeMemory) {
        // --- MEMORY STORE ---
        final contentToSave = intentService.extractMemoryContent(text);
        await memoryService.saveMemory(contentToSave);
        _updateLastMessage("I've saved that to your memory.");
      } else if (intent == IntentType.webSearch) {
        // --- WEB SEARCH ---
        final searchQuery = intentService.extractSearchQuery(text);
        _updateLastMessage('Searching the web...');

        final results = await webSearchService.search(searchQuery);
        if (results.isEmpty) {
          _updateLastMessage(
              'No results found. You may be offline or the search failed.');
        } else {
          // Build context with search results and pass to LLM
          final fullPrompt = await contextBuilder.buildPrompt(
            userMessage: text,
            chatHistory: _recentHistory(),
            includeMemories: false,
            includeDocuments: false,
            includeWebSearch: true,
          );

          final stream = llmService.chat(
            text,
            systemPrompt: fullPrompt,
            maxTokens: 768,
          );

          String fullResponse = '';
          await for (final chunk in stream) {
            fullResponse += chunk;
            _updateLastMessage(fullResponse);
          }

          if (fullResponse.isEmpty) {
            // Fallback: show raw results if LLM didn't respond
            final formatted =
                webSearchService.formatResultsAsContext(results);
            _updateLastMessage(formatted);
          }
        }
      } else {
        // --- CHAT / RAG / MEMORY RETRIEVAL ---
        final fullPrompt = await contextBuilder.buildPrompt(
          userMessage: text,
          chatHistory: _recentHistory(),
          includeMemories:
              intent == IntentType.retrieveMemory ||
              intent == IntentType.normalChat,
          includeDocuments:
              intent == IntentType.queryDocument ||
              intent == IntentType.normalChat,
        );

        final stream = llmService.chat(text, systemPrompt: fullPrompt);

        String fullResponse = '';
        await for (final chunk in stream) {
          fullResponse += chunk;
          _updateLastMessage(fullResponse);
        }

        if (fullResponse.isEmpty) {
          _updateLastMessage(
              'I could not generate a response. Please check if a model is loaded.');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in sendMessage: $e');
      _updateLastMessage('Error: $e');
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
        // Thinking complete — extract and separate
        thinking = match.group(1)?.trim() ?? '';
        content = rawContent.replaceAll(thinkRegex, '').trim();
        thinkingDone = 'true';
      } else if (rawContent.contains('<think>') &&
          !rawContent.contains('</think>')) {
        // Thinking still streaming — no closing tag yet
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
