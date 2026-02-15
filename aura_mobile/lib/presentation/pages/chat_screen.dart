import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _hasText = false;
  bool _isNearBottom = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    _isNearBottom = (maxScroll - currentScroll) < 100;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;
    if (!force && !_isNearBottom) return;

    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(chatProvider.notifier).sendMessage(text);
    _controller.clear();
    _isNearBottom = true;
    _scrollToBottom(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // Auto-scroll during streaming only if user is near bottom
    if (chatState.isThinking && _isNearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    // Responsive content width
    final maxContentWidth = screenWidth > 768 ? 720.0 : screenWidth;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── Header ───
            _buildHeader(context),

            // ─── Model loading indicator ───
            _buildModelLoadingBanner(),

            // ─── Messages ───
            Expanded(
              child: chatState.messages.isEmpty
                  ? _buildEmptyState(screenWidth)
                  : _buildMessageList(chatState, maxContentWidth),
            ),

            // ─── Stop button ───
            if (chatState.isThinking)
              _buildStopButton(),

            // ─── Input Bar ───
            _buildInputBar(chatState, bottomInset, bottomPad, maxContentWidth),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          // New chat
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 22, color: AppTheme.textSecondary),
            onPressed: () => ref.read(chatProvider.notifier).clearChat(),
            tooltip: 'New chat',
          ),
          const Spacer(),
          // Model selector
          Consumer(
            builder: (context, ref, _) {
              final modelState = ref.watch(modelSelectorProvider);
              final activeModel = modelState.activeModelId != null
                  ? modelState.availableModels
                      .where((m) => m.id == modelState.activeModelId)
                      .firstOrNull
                  : null;
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ModelSelectorScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeModel?.name ?? 'Select Model',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          // Upload doc
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, size: 22, color: AppTheme.textSecondary),
            onPressed: _uploadDocument,
            tooltip: 'Upload document',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Model loading banner
  // ─────────────────────────────────────────────
  Widget _buildModelLoadingBanner() {
    return Consumer(
      builder: (context, ref, _) {
        final modelState = ref.watch(modelSelectorProvider);

        if (modelState.modelLoadError != null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.error.withValues(alpha: 0.15),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    modelState.modelLoadError!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }

        if (modelState.isLoadingModel) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.accent.withValues(alpha: 0.1),
            child: Row(
              children: [
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading model...',
                  style: TextStyle(color: AppTheme.accent, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  // ─────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────
  Widget _buildEmptyState(double screenWidth) {
    final isCompact = screenWidth < 400;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 24 : 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: isCompact ? 48 : 64,
              height: isCompact ? 48 : 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accent, Color(0xFF0D8C6D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isCompact ? 24 : 32),
              ),
              child: Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 24 : 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: isCompact ? 16 : 24),
            Text(
              'How can I help you today?',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: isCompact ? 18 : 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask anything, upload documents, or save memories',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: isCompact ? 13 : 14,
              ),
            ),
            const SizedBox(height: 32),
            // Quick action chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('What can you do?'),
                _buildSuggestionChip('Search the web'),
                _buildSuggestionChip('Remember that...'),
                _buildSuggestionChip('Read my messages'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        setState(() => _hasText = true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Text(
          text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Message list
  // ─────────────────────────────────────────────
  Widget _buildMessageList(ChatState chatState, double maxContentWidth) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final msg = chatState.messages[index];
        final isUser = msg['role'] == 'user';
        final content = msg['content'] ?? '';
        final thinking = msg['thinking'];
        final thinkingDone = msg['thinkingDone'] == 'true';
        final isLast = index == chatState.messages.length - 1;
        final isStreaming = isLast && !isUser && chatState.isThinking;

        if (isUser) {
          return _UserBubble(content: content, maxWidth: maxContentWidth);
        }

        // Show typing dots for empty streaming placeholder
        if (content.isEmpty && (thinking == null || thinking.isEmpty)) {
          if (isStreaming) {
            return _TypingDots(maxWidth: maxContentWidth);
          }
          return const SizedBox.shrink();
        }

        return _AssistantMessage(
          content: content,
          thinking: thinking,
          thinkingDone: thinkingDone,
          isStreaming: isStreaming,
          maxWidth: maxContentWidth,
          messageIndex: index,
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Stop generation button
  // ─────────────────────────────────────────────
  Widget _buildStopButton() {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => ref.read(chatProvider.notifier).stopGeneration(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stop_circle_outlined, size: 18, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Text(
                'Stop generating',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Input bar
  // ─────────────────────────────────────────────
  Widget _buildInputBar(ChatState chatState, double bottomInset, double bottomPad, double maxWidth) {
    final effectiveBottomPad = bottomInset > 0 ? 8.0 : (bottomPad > 0 ? bottomPad : 16.0);

    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, effectiveBottomPad),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Mic button
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: IconButton(
                    icon: Icon(
                      chatState.isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: chatState.isListening ? AppTheme.accent : AppTheme.textMuted,
                      size: 22,
                    ),
                    onPressed: () {
                      if (chatState.isListening) {
                        ref.read(chatProvider.notifier).stopListening();
                      } else {
                        ref.read(chatProvider.notifier).startListening();
                      }
                    },
                    tooltip: chatState.isListening ? 'Stop listening' : 'Voice input',
                  ),
                ),
                // Text input
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 6,
                    minLines: 1,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Message AURA',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                // Send button
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 6),
                  child: GestureDetector(
                    onTap: _hasText && !chatState.isThinking ? _sendMessage : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _hasText && !chatState.isThinking
                            ? AppTheme.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: _hasText && !chatState.isThinking
                            ? Colors.white
                            : AppTheme.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _uploadDocument() async {
    try {
      final filename = await ref.read(documentServiceProvider).pickAndProcessDocument();
      if (filename != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded: $filename'),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────
// User Bubble — right-aligned, rounded
// ─────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final String content;
  final double maxWidth;
  const _UserBubble({required this.content, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleMaxWidth = screenWidth * 0.78;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(48, 4, 16, 4),
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SelectableText(
          content,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, height: 1.45),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Assistant Message — left-aligned, flat text with avatar
// ─────────────────────────────────────────────
class _AssistantMessage extends StatelessWidget {
  final String content;
  final String? thinking;
  final bool thinkingDone;
  final bool isStreaming;
  final double maxWidth;
  final int messageIndex;

  const _AssistantMessage({
    required this.content,
    this.thinking,
    required this.thinkingDone,
    this.isStreaming = false,
    required this.maxWidth,
    required this.messageIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 32, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accent, Color(0xFF0D8C6D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thinking bubble
                if (thinking != null && thinking!.isNotEmpty)
                  _ThinkingBubble(thinking: thinking!, isDone: thinkingDone),
                // Response text
                if (content.isNotEmpty)
                  _MessageContent(content: content),
                // Streaming cursor
                if (isStreaming && content.isNotEmpty)
                  const _BlinkingCursor(),
                // Action bar
                if (!isStreaming && content.isNotEmpty)
                  _ActionBar(content: content, messageIndex: messageIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Message content with markdown
// ─────────────────────────────────────────────
class _MessageContent extends StatelessWidget {
  final String content;
  const _MessageContent({required this.content});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, height: 1.55),
        h1: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
        h2: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        h3: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        code: TextStyle(
          color: AppTheme.accent,
          backgroundColor: AppTheme.sidebar,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
        codeblockPadding: const EdgeInsets.all(14),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.sidebar,
          borderRadius: BorderRadius.circular(8),
        ),
        listBullet: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        strong: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        em: const TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
        blockquote: const TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.textMuted, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
        a: const TextStyle(color: AppTheme.accent, decoration: TextDecoration.underline),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Action bar (copy)
// ─────────────────────────────────────────────
class _ActionBar extends ConsumerWidget {
  final String content;
  final int messageIndex;
  const _ActionBar({required this.content, required this.messageIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final isSpeakingThis = chatState.isSpeaking && chatState.speakingMessageIndex == messageIndex;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _ActionIcon(
            icon: Icons.content_copy_rounded,
            tooltip: 'Copy',
            onTap: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Copied to clipboard'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: AppTheme.surface,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          _ActionIcon(
            icon: isSpeakingThis ? Icons.stop_rounded : Icons.volume_up_rounded,
            tooltip: isSpeakingThis ? 'Stop reading' : 'Read aloud',
            onTap: () {
              if (isSpeakingThis) {
                ref.read(chatProvider.notifier).stopSpeaking();
              } else {
                ref.read(chatProvider.notifier).speakMessage(content, messageIndex);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: AppTheme.textMuted),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Thinking Bubble — collapsible
// ─────────────────────────────────────────────
class _ThinkingBubble extends StatefulWidget {
  final String thinking;
  final bool isDone;
  const _ThinkingBubble({required this.thinking, required this.isDone});

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (!widget.isDone) {
      _expanded = true;
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _ThinkingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDone && !oldWidget.isDone) {
      setState(() => _expanded = false);
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.isDone
                ? () {
                    setState(() => _expanded = !_expanded);
                    _expanded ? _controller.forward() : _controller.reverse();
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7c3aed).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isDone) ...[
                    const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF7c3aed),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Thinking...',
                      style: TextStyle(color: Color(0xFF7c3aed), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ] else ...[
                    Icon(
                      _expanded ? Icons.expand_less : Icons.chevron_right,
                      size: 16,
                      color: const Color(0xFF7c3aed),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Thought process',
                      style: TextStyle(color: Color(0xFF7c3aed), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _animation,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.sidebar,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7c3aed).withValues(alpha: 0.2)),
              ),
              child: Text(
                widget.thinking,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
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

// ─────────────────────────────────────────────
// Typing Dots — animated bouncing
// ─────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  final double maxWidth;
  const _TypingDots({required this.maxWidth});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    ));
    _anims = _ctrls.map((c) => Tween(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: c, curve: Curves.easeInOut),
    )).toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 32, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accent, Color(0xFF0D8C6D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('A', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: List.generate(3, (i) => AnimatedBuilder(
                animation: _anims[i],
                builder: (_, _) => Transform.translate(
                  offset: Offset(0, _anims[i].value),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Blinking cursor for streaming
// ─────────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Opacity(
        opacity: _controller.value,
        child: Container(
          width: 2, height: 18,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
