import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_mobile/presentation/providers/chat_provider.dart';
import 'package:aura_mobile/presentation/providers/model_selector_provider.dart';
import 'package:aura_mobile/presentation/pages/model_selector_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    // Scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0c), // Obsidian
      appBar: AppBar(
        title: Consumer(
          builder: (context, ref, _) {
            final modelState = ref.watch(modelSelectorProvider);
            final activeModel = modelState.activeModelId != null
                ? modelState.availableModels.firstWhere(
                    (m) => m.id == modelState.activeModelId,
                    orElse: () => modelState.availableModels.first,
                  )
                : null;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AURA Mobile',
                  style: TextStyle(color: Color(0xFFe6cf8e), fontSize: 18),
                ),
                if (activeModel != null)
                  Text(
                    activeModel.name,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            );
          },
        ),
        backgroundColor: const Color(0xFF141418), // Obsidian Light
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology, color: Color(0xFFc69c3a)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ModelSelectorScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to AURA\nI am ready to help.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF2a2a30) : const Color(0xFF1a1a20),
                            borderRadius: BorderRadius.circular(12).copyWith(
                              bottomRight: isUser ? Radius.zero : null,
                              bottomLeft: !isUser ? Radius.zero : null,
                            ),
                            border: Border.all(
                              color: const Color(0xFFc69c3a).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            msg['content'] ?? '',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (chatState.isThinking)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Color(0xFFc69c3a),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF141418),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ask AURA...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0a0a0c),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (value) {
                       if (value.trim().isNotEmpty) {
                        ref.read(chatProvider.notifier).sendMessage(value);
                        _controller.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(chatState.isListening ? Icons.mic_off : Icons.mic, color: const Color(0xFFc69c3a)),
                  onPressed: () {
                    if (chatState.isListening) {
                      ref.read(chatProvider.notifier).stopListening();
                    } else {
                      ref.read(chatProvider.notifier).startListening();
                    }
                  },
                ),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFe6cf8e), Color(0xFFc69c3a)],
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF0a0a0c)),
                    onPressed: () {
                      if (_controller.text.trim().isNotEmpty) {
                        ref.read(chatProvider.notifier).sendMessage(_controller.text);
                        _controller.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
