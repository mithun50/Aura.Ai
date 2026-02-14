import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aura_mobile/presentation/providers/chat_provider.dart';
import 'package:aura_mobile/presentation/providers/model_selector_provider.dart';
import 'package:aura_mobile/presentation/pages/model_selector_screen.dart';
import 'package:aura_mobile/domain/services/document_service.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0c),
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
        backgroundColor: const Color(0xFF141418),
        elevation: 0,
        actions: [
          // Upload PDF button
          IconButton(
            icon: const Icon(Icons.attach_file, color: Color(0xFFc69c3a)),
            onPressed: () {
              ref.read(documentServiceProvider).pickAndProcessDocument();
            },
            tooltip: 'Upload PDF',
          ),
          // Model selector
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
                        const Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to AURA\nI am ready to help.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.2),
                              fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Try: "search Flutter latest news"\n'
                          '"remember that my meeting is tomorrow at 3 PM"\n'
                          '"what did I save?"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.15),
                            fontSize: 13,
                          ),
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
                      final content = msg['content'] ?? '';
                      final thinking = msg['thinking'];
                      final thinkingDone = msg['thinkingDone'] == 'true';

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.85,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thinking bubble (for models with <think> tags)
                              if (!isUser &&
                                  thinking != null &&
                                  thinking.isNotEmpty)
                                _ThinkingBubble(
                                  thinking: thinking,
                                  isDone: thinkingDone,
                                ),
                              // Main message bubble
                              if (isUser || content.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? const Color(0xFF2a2a30)
                                        : const Color(0xFF1a1a20),
                                    borderRadius:
                                        BorderRadius.circular(12).copyWith(
                                      bottomRight:
                                          isUser ? Radius.zero : null,
                                      bottomLeft:
                                          !isUser ? Radius.zero : null,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFc69c3a)
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: isUser
                                      ? Text(
                                          content,
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        )
                                      : MarkdownBody(
                                          data: content,
                                          styleSheet: MarkdownStyleSheet(
                                            p: const TextStyle(
                                                color: Colors.white70),
                                            h1: const TextStyle(
                                                color: Color(0xFFe6cf8e)),
                                            h2: const TextStyle(
                                                color: Color(0xFFe6cf8e)),
                                            code: const TextStyle(
                                              color: Color(0xFFc69c3a),
                                              backgroundColor:
                                                  Color(0xFF0f0f14),
                                            ),
                                            codeblockDecoration:
                                                BoxDecoration(
                                              color:
                                                  const Color(0xFF0f0f14),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            listBullet: const TextStyle(
                                                color: Colors.white54),
                                            strong: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                ),
                            ],
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
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0a0a0c),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        ref
                            .read(chatProvider.notifier)
                            .sendMessage(value);
                        _controller.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                      chatState.isListening ? Icons.mic_off : Icons.mic,
                      color: const Color(0xFFc69c3a)),
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
                    icon:
                        const Icon(Icons.send, color: Color(0xFF0a0a0c)),
                    onPressed: () {
                      if (_controller.text.trim().isNotEmpty) {
                        ref
                            .read(chatProvider.notifier)
                            .sendMessage(_controller.text);
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

/// Collapsible thinking/reasoning bubble — similar to ChatGPT's "Thought for X seconds"
class _ThinkingBubble extends StatefulWidget {
  final String thinking;
  final bool isDone;

  const _ThinkingBubble({required this.thinking, required this.isDone});

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    // Auto-expand while thinking is in progress
    if (!widget.isDone) {
      _expanded = true;
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _ThinkingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-collapse when thinking finishes
    if (widget.isDone && !oldWidget.isDone) {
      setState(() => _expanded = false);
      _animController.reverse();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF12121a),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFc69c3a).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — tap to toggle
          InkWell(
            onTap: widget.isDone ? _toggle : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (!widget.isDone) ...[
                    // Animated thinking indicator
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFFc69c3a).withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thinking...',
                      style: TextStyle(
                        color:
                            const Color(0xFFc69c3a).withValues(alpha: 0.7),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.psychology,
                      size: 16,
                      color:
                          const Color(0xFFc69c3a).withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thought process',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Expandable thinking content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                widget.thinking,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
