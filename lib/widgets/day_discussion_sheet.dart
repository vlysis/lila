import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../services/ai_api_types.dart';
import '../services/ai_chat_client.dart';
import '../services/file_service.dart';
import '../theme/lila_theme.dart';

/// A chat message in the discussion.
class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;

  _ChatMessage({required this.role, required this.content});
}

/// Bottom sheet for discussing the day with AI.
class DayDiscussionSheet extends StatefulWidget {
  final DateTime date;
  final List<LogEntry> entries;
  final String reflectionText;

  const DayDiscussionSheet({
    super.key,
    required this.date,
    required this.entries,
    required this.reflectionText,
  });

  @override
  State<DayDiscussionSheet> createState() => _DayDiscussionSheetState();
}

class _DayDiscussionSheetState extends State<DayDiscussionSheet> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();

  List<_ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _errorMessage;
  bool _canRetry = false;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _loadExistingDiscussion();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadExistingDiscussion() async {
    final fs = await FileService.getInstance();
    final markdown = await fs.readDiscussion(widget.date);

    if (markdown != null) {
      _parseDiscussionMarkdown(markdown);
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _parseDiscussionMarkdown(String markdown) {
    final messages = <_ChatMessage>[];
    final lines = markdown.split('\n');
    String? currentRole;
    final contentBuffer = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('**User:** ')) {
        if (currentRole != null) {
          messages.add(_ChatMessage(
            role: currentRole,
            content: contentBuffer.toString().trim(),
          ));
        }
        currentRole = 'user';
        contentBuffer.clear();
        contentBuffer.write(line.substring('**User:** '.length));
      } else if (line.startsWith('**Assistant:** ') ||
          line.startsWith('**Claude:** ')) {
        if (currentRole != null) {
          messages.add(_ChatMessage(
            role: currentRole,
            content: contentBuffer.toString().trim(),
          ));
        }
        currentRole = 'assistant';
        contentBuffer.clear();
        final label = line.startsWith('**Assistant:** ')
            ? '**Assistant:** '
            : '**Claude:** ';
        contentBuffer.write(line.substring(label.length));
      } else if (currentRole != null) {
        contentBuffer.write('\n$line');
      }
    }

    if (currentRole != null && contentBuffer.isNotEmpty) {
      messages.add(_ChatMessage(
        role: currentRole,
        content: contentBuffer.toString().trim(),
      ));
    }

    _messages = messages;
  }

  String _buildDiscussionMarkdown() {
    final buffer = StringBuffer();
    for (final msg in _messages) {
      final roleLabel = msg.role == 'user' ? 'User' : 'Assistant';
      buffer.writeln('**$roleLabel:** ${msg.content}');
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  Future<void> _saveDiscussion() async {
    if (_messages.isEmpty) return;
    final fs = await FileService.getInstance();
    await fs.saveDiscussion(widget.date, _buildDiscussionMarkdown());
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _saveDiscussion);
  }

  String _buildSystemPrompt() {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(widget.date);

    final entriesBuffer = StringBuffer();
    for (final entry in widget.entries) {
      final time =
          '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
      final label = entry.label ?? entry.mode.label;
      entriesBuffer.writeln(
          '- $time: $label (${entry.mode.name}, ${entry.orientation.label})');
    }

    final entriesText = widget.entries.isEmpty
        ? 'No moments logged yet.'
        : entriesBuffer.toString().trim();

    final reflectionText = widget.reflectionText.isEmpty
        ? '(No reflection written yet)'
        : '"${widget.reflectionText}"';

    return '''You are a gentle, observational companion in Lila, a mindful activity logger.
The user is reflecting on their day. Be curious and supportive, never prescriptive or productivity-focused. Drift is not negative. All modes have equal value.

Today is $dateStr.

The user logged these moments:
$entriesText

Their reflection so far: $reflectionText

Ask thoughtful questions. Make gentle observations. Keep responses concise (2-3 sentences).''';
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _inputController.clear();
      _sending = true;
      _errorMessage = null;
      _canRetry = false;
    });

    _scrollToBottom();

    final client = await AiChatClient.getInstance();

    // Build message history for API
    final history = _messages
        .take(_messages.length - 1) // Exclude the message we just added
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final result = await client.sendMessage(
      message: text,
      systemPrompt: _buildSystemPrompt(),
      messageHistory: history.isEmpty ? null : history,
      maxTokens: 512,
    );

    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', content: result.data!));
        _sending = false;
      });
      _scheduleSave();
      _scrollToBottom();
    } else {
      setState(() {
        _sending = false;
        _errorMessage = result.error?.userMessage ?? 'An error occurred.';
        _canRetry = result.error?.isRetryable ?? false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _retry() {
    if (_messages.isNotEmpty && _messages.last.role == 'user') {
      final lastMessage = _messages.removeLast();
      _inputController.text = lastMessage.content;
      setState(() {
        _errorMessage = null;
        _canRetry = false;
      });
      _sendMessage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.lilaSurface;
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: bottomInset),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: s.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discuss your day',
                        style: TextStyle(
                          color: s.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: s.textMuted,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(color: colorScheme.outline.withValues(alpha: 0.3), height: 1),
                // Messages
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : GestureDetector(
                          onTap: () => _inputFocusNode.unfocus(),
                          child: _messages.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  itemCount: _messages.length +
                                      (_sending ? 1 : 0) +
                                      (_errorMessage != null ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index < _messages.length) {
                                      return _buildMessageBubble(
                                          _messages[index]);
                                    } else if (_sending) {
                                      return _buildTypingIndicator();
                                    } else if (_errorMessage != null) {
                                      return _buildErrorMessage();
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                        ),
                ),
                // Input area
                _buildInputArea(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final s = context.lilaSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: s.textFaint,
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation about your day',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: s.textMuted,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final s = context.lilaSurface;
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? s.overlay
              : const Color(0xFF6B8F71).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: s.text,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF6B8F71).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final s = context.lilaSurface;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: s.textMuted.withValues(alpha: value * 0.8),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildErrorMessage() {
    final s = context.lilaSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFA87B6B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: const Color(0xFFA87B6B).withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: s.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (_canRetry)
            TextButton(
              onPressed: _retry,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: const Color(0xFF7B9EA8).withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final s = context.lilaSurface;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: s.text,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: TextStyle(
                  color: s.textFaint,
                ),
                filled: true,
                fillColor: s.overlay.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF6B8F71).withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_upward,
                color: _sending
                    ? s.textFaint
                    : Colors.white,
                size: 20,
              ),
              onPressed: _sending ? null : _sendMessage,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
