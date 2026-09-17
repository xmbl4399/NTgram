import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/chat.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/chat/message_content_widget.dart';
import 'package:native_tavern/presentation/widgets/chat/data_bank_citation_preview.dart';
import 'package:native_tavern/presentation/widgets/chat/reasoning_widget.dart';

/// Visual novel style message view.
///
/// One message per page; swipe left/right to turn pages. There are no chevron
/// buttons — the only chrome is a translucent `n / total` counter that sits
/// directly on top of the bubble, horizontally centred. Long-pressing that
/// counter opens the same message menu the bubble used to open (that gesture is
/// unreliable on the bubble itself because the reply text is selectable).
///
/// The bubble follows the classic bubble layout (same colours, radius and
/// left/right alignment as `_MessageBubble`), hugs the bottom edge and only
/// takes the height it needs — the artwork above stays visible.
class VisualNovelMessageView extends ConsumerStatefulWidget {
  final List<ChatMessage> messages;
  final Character? character;
  final Character? Function(ChatMessage message)? characterForMessage;
  final bool isGenerating;
  final void Function(ChatMessage message) onLongPress;
  final void Function(int swipeIndex, String messageId) onSwipe;

  /// When true the pager fills the space given by the parent (novel mode) instead
  /// of capping at ~50% of the screen height.
  final bool fillsAvailable;

  /// Whether an image background is active — drives bubble translucency, exactly
  /// like bubble mode.
  final bool hasBackground;

  /// Bubble opacity when [hasBackground] is true.
  final double bubbleOpacity;

  const VisualNovelMessageView({
    super.key,
    required this.messages,
    this.character,
    this.characterForMessage,
    this.isGenerating = false,
    required this.onLongPress,
    required this.onSwipe,
    this.fillsAvailable = false,
    this.hasBackground = false,
    this.bubbleOpacity = 0.8,
  });

  @override
  ConsumerState<VisualNovelMessageView> createState() =>
      _VisualNovelMessageViewState();
}

class _VisualNovelMessageViewState
    extends ConsumerState<VisualNovelMessageView> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.messages.isEmpty ? 0 : widget.messages.length - 1;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(VisualNovelMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto scroll to latest message when new message arrives
    if (widget.messages.length > oldWidget.messages.length) {
      final newIndex = widget.messages.length - 1;
      if (_currentIndex != newIndex) {
        setState(() => _currentIndex = newIndex);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              newIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const SizedBox.shrink();
    }

    // Just the pager: the page counter lives inside each page (above the
    // bubble), so nothing is reserved below it and the bubble can sit lower.
    return _buildPager();
  }

  // ------------------------------------------------------------------ chrome

  /// The `n / total` pill that floats directly above the bubble.
  ///
  /// Visual style is taken verbatim from the upstream (`fatsnk/NativeTavern`)
  /// navigation bar: a `Colors.black38` pill, 20 radius, 16/6 padding, white
  /// 13px medium text. Only its *position* changed — upstream drew it in a
  /// chrome row at the top, here it sits centred on top of the bubble so the
  /// bubble can rest lower.
  ///
  /// Long-press opens the message menu — this is the visual-novel equivalent of
  /// the old "long-press the speaker name" gesture.
  Widget _buildPageChip(ChatMessage message, int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => widget.onLongPress(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${index + 1} / ${widget.messages.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- pager

  Widget _buildPager() {
    final pager = PageView.builder(
      controller: _pageController,
      itemCount: widget.messages.length,
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
      },
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        final isLast = index == widget.messages.length - 1;
        final isGenerating = isLast && widget.isGenerating;
        return _buildMessageCard(message, isGenerating, index);
      },
    );

    if (widget.fillsAvailable) {
      return pager;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        minHeight: 120,
      ),
      child: pager,
    );
  }

  // ------------------------------------------------------------------ bubble

  Widget _buildMessageCard(
    ChatMessage message,
    bool isGenerating,
    int index,
  ) {
    final isUser = message.role == MessageRole.user;
    final hasSwipes = message.swipes.length > 1;
    final isLast =
        widget.messages.isNotEmpty && message == widget.messages.last;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The page, not the screen, is the real budget: the chat area already
        // excludes the top bar and the input bar, and with the keyboard open it
        // is much shorter than the screen. Capping the bubble at half the
        // *screen* overflowed the column by ~17px whenever the counter chip and
        // paddings were added on top of that cap. Half of the page keeps the
        // artwork visible and always fits.
        final pageHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.5;
        final maxBubbleHeight = pageHeight * 0.5;

        return Align(
          // Counter + bubble hug the bottom edge; the artwork above stays
          // uncovered. No speaker name and no avatar here — the sprite is the
          // speaker.
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Page counter sits tight on top of the bubble, centred on screen.
                Center(child: _buildPageChip(message, index)),
                const SizedBox(height: 6),
                // Flexible is the overflow guard: whatever the chip and the
                // paddings actually consume, the bubble shrinks into what is
                // left instead of pushing the column past the page.
                Flexible(
                  child: Row(
                    // Same geometry as bubble mode: the bubble hugs its own side
                    // and may grow to the full row width; it is never
                    // artificially narrowed.
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onLongPress: () => widget.onLongPress(message),
                          child: Container(
                            constraints:
                                BoxConstraints(maxHeight: maxBubbleHeight),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: _buildBubbleDecoration(isUser),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Show reasoning/thinking content (AI messages only)
                                  if (!isUser && message.hasReasoning) ...[
                                    _buildReasoningSection(
                                      message,
                                      isGenerating && isLast,
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  if (isGenerating && message.content.isEmpty)
                                    _buildTypingIndicator()
                                  else
                                    MessageContentWidget(
                                      content: message.content,
                                      textColor: isUser
                                          ? Colors.white
                                          : context.neko.textPrimary,
                                      selectable: true,
                                      onLongPress: () =>
                                          widget.onLongPress(message),
                                      isStreaming: isGenerating,
                                      messageId: message.id,
                                    ),
                                  if (!isUser && !isGenerating)
                                    DataBankCitationPreview(message: message),
                                  if (hasSwipes && !isGenerating)
                                    _buildSwipeControls(message),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isUser) const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Same colour rules as bubble mode (`_MessageBubble._buildMessageDecoration`).
  BoxDecoration _buildBubbleDecoration(bool isUser) {
    final neko = context.neko;
    final base = isUser ? neko.userBubble : neko.card;
    final color = widget.hasBackground
        ? base.withValues(alpha: widget.bubbleOpacity)
        : base;

    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    );
  }

  /// Build the reasoning/thinking section for AI messages
  Widget _buildReasoningSection(ChatMessage message, bool isStreaming) {
    final l10n = AppLocalizations.of(context);
    final reasoning = message.currentReasoning;
    if (reasoning == null || reasoning.isEmpty) {
      return const SizedBox.shrink();
    }

    // During streaming, show the streaming version
    if (isStreaming) {
      return StreamingReasoningWidget(
        reasoning: reasoning,
        isStreaming: true,
        label: l10n.thinking,
      );
    }

    // For completed messages, show the collapsible version
    return ReasoningWidget(
      reasoning: reasoning,
      initiallyExpanded: false,
      label: l10n.thinking,
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 600 + i * 200),
              builder: (context, value, child) => Opacity(
                opacity: 0.3 + 0.7 * ((value + i / 3) % 1),
                child: child,
              ),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.neko.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSwipeControls(ChatMessage message) {
    final neko = context.neko;
    final currentSwipeIndex = message.currentSwipeIndex;
    final totalSwipes = message.swipes.length;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              size: 14,
              color:
                  currentSwipeIndex > 0 ? neko.textSecondary : neko.textMuted,
            ),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            onPressed: currentSwipeIndex > 0
                ? () => widget.onSwipe(currentSwipeIndex - 1, message.id)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${currentSwipeIndex + 1} / $totalSwipes',
              style: TextStyle(color: neko.textSecondary, fontSize: 12),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: currentSwipeIndex < totalSwipes - 1
                  ? neko.textSecondary
                  : neko.textMuted,
            ),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            onPressed: currentSwipeIndex < totalSwipes - 1
                ? () => widget.onSwipe(currentSwipeIndex + 1, message.id)
                : null,
          ),
        ],
      ),
    );
  }
}
