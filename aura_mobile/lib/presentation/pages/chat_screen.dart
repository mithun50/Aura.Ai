import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aura_mobile/presentation/providers/chat_provider.dart';
import 'package:aura_mobile/presentation/providers/model_selector_provider.dart';
import 'package:aura_mobile/presentation/pages/model_selector_screen.dart';
import 'package:aura_mobile/domain/services/document_service.dart';
import 'package:aura_mobile/core/theme/app_theme.dart';

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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Consumer(
          builder: (context, ref, _) {
            final modelState = ref.watch(modelSelectorProvider);
            final activeModel = modelState.activeModelId != null
                ? modelState.availableModels
                    .where((m) => m.id == modelState.activeModelId)
                    .firstOrNull
                : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AURA',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (activeModel != null)
                  Text(
                    activeModel.name,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            );
          },
        ),
        backgroundColor: AppTheme.sidebar,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: AppTheme.textSecondary),
            onPressed: () async {
              try {
                final filename = await ref
                    .read(documentServiceProvider)
                    .pickAndProcessDocument();
                if (filename != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Uploaded: $filename'),
                      backgroundColor: AppTheme.accent,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            tooltip: 'Upload document',
          ),
          IconButton(
            icon: const Icon(Icons.psychology, color: AppTheme.textSecondary),
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
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 24,
                            color: AppTheme.accent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'How can I help you today?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Ask me anything, search the web,\nor upload a document to analyze.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      final isUser = msg['role'] == 'user';
                      final content = msg['content'] ?? '';
                      final thinking = msg['thinking'];
                      final thinkingDone = msg['thinkingDone'] == 'true';

                      if (isUser) {
                        return _UserBubble(content: content);
                      }

                      return _AssistantMessage(
                        content: content,
                        thinking: thinking,
                        thinkingDone: thinkingDone,
                      );
                    },
                  ),
          ),
          if (chatState.isThinking) const _TypingIndicator(),
          _InputBar(
            controller: _controller,
            isListening: chatState.isListening,
            onSend: (value) {
              if (value.trim().isNotEmpty) {
                ref.read(chatProvider.notifier).sendMessage(value);
                _controller.clear();
              }
            },
            onMicToggle: () {
              if (chatState.isListening) {
                ref.read(chatProvider.notifier).stopListening();
              } else {
                ref.read(chatProvider.notifier).startListening();
              }
            },
          ),
        ],
      ),
    );
  }
}

/// User message bubble — subtle rounded container
class _UserBubble extends StatelessWidget {
  final String content;
  const _UserBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: AppTheme.userBubble,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          content,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        ),
      ),
    );
  }
}

/// Assistant message — flat, full-width, no border (ChatGPT style)
class _AssistantMessage extends StatelessWidget {
  final String content;
  final String? thinking;
  final bool thinkingDone;

  const _AssistantMessage({
    required this.content,
    this.thinking,
    required this.thinkingDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small circular AURA avatar
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 4, right: 12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 14,
              color: AppTheme.accent,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thinking bubble
                if (thinking != null && thinking!.isNotEmpty)
                  _ThinkingBubble(
                    thinking: thinking!,
                    isDone: thinkingDone,
                  ),
                // Main content
                if (content.isNotEmpty)
                  MarkdownBody(
                    data: content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                      h1: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      code: TextStyle(
                        color: AppTheme.accent,
                        backgroundColor: AppTheme.sidebar,
                        fontSize: 13,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: AppTheme.sidebar,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      listBullet: const TextStyle(color: AppTheme.textSecondary),
                      strong: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
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

/// Collapsible thinking bubble — "Thought for X seconds" style
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
    if (!widget.isDone) {
      _expanded = true;
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _ThinkingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.isDone ? _toggle : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isDone) ...[
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thinking...',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      _expanded ? Icons.expand_less : Icons.chevron_right,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Thought process',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.sidebar,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.thinking,
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated typing dots indicator
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 14,
              color: AppTheme.accent,
            ),
          ),
          Row(
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _animations[i],
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _animations[i].value),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Flat input bar with rounded text field
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final void Function(String) onSend;
  final VoidCallback onMicToggle;

  const _InputBar({
    required this.controller,
    required this.isListening,
    required this.onSend,
    required this.onMicToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      color: AppTheme.sidebar,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Message AURA...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.inputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              onSubmitted: onSend,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              isListening ? Icons.mic_off : Icons.mic,
              color: isListening ? AppTheme.accent : AppTheme.textSecondary,
            ),
            onPressed: onMicToggle,
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              onPressed: () => onSend(controller.text),
            ),
          ),
        ],
      ),
    );
  }
}
