import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vietspots/models/chat_model.dart';
import 'package:vietspots/providers/chat_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/widgets/place_card.dart';
import 'package:vietspots/utils/typography.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  int _lastRenderedItemCount = 0;

  void _sendMessage() {
    final provider = Provider.of<ChatProvider>(context, listen: false);
    if (provider.isLoading) return;
    if (_controller.text.trim().isEmpty) return;
    provider.sendMessage(_controller.text);
    _controller.clear();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startNewChat() {
    final loc = Provider.of<LocalizationProvider>(context, listen: false);
    Provider.of<ChatProvider>(context, listen: false).clearMessages();
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.translate('new_chat_started'))));
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final loc = Provider.of<LocalizationProvider>(context);
    final isTyping = chatProvider.isLoading;
    final currentItemCount = chatProvider.messages.length + (isTyping ? 1 : 0);
    if (currentItemCount != _lastRenderedItemCount && currentItemCount > 0) {
      _lastRenderedItemCount = currentItemCount;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          chatProvider.activeTitle,
          style: AppTypography.titleLarge.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.redAccent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            tooltip: loc.translate('close_chat'),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                loc.translate('ai_name'),
                style: AppTypography.titleMedium.copyWith(color: Colors.white),
              ),
              accountEmail: Text(
                loc.translate('ai_subtitle'),
                style: AppTypography.bodySmall.copyWith(color: Colors.white70),
              ),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.smart_toy),
              ),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(loc.translate('new_chat')),
              onTap: _startNewChat,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                loc.translate('history'),
                style: AppTypography.sectionHeader.copyWith(
                  color: AppTextColors.tertiary(context),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: chatProvider.history.isEmpty
                    ? [
                        ListTile(
                          title: Text(loc.translate('no_conversations_yet')),
                          subtitle: Text(
                            loc.translate('start_chatting_history'),
                          ),
                        ),
                      ]
                    : chatProvider.history.map((conv) {
                        return ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(conv.title),
                          subtitle: Text(_timeAgo(conv.updatedAt)),
                          onTap: () {
                            Navigator.pop(context);
                            Provider.of<ChatProvider>(
                              context,
                              listen: false,
                            ).loadConversation(conv.id);
                          },
                          onLongPress: () async {
                            final choice = await showModalBottomSheet<String>(
                              context: context,
                              builder: (ctx) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        title: Text(loc.translate('open')),
                                        onTap: () => Navigator.pop(ctx, 'open'),
                                      ),
                                      ListTile(
                                        title: Text(loc.translate('save')),
                                        onTap: () => Navigator.pop(ctx, 'save'),
                                      ),
                                      ListTile(
                                        title: Text(loc.translate('share')),
                                        onTap: () =>
                                            Navigator.pop(ctx, 'share'),
                                      ),
                                      ListTile(
                                        title: Text(loc.translate('delete')),
                                        onTap: () =>
                                            Navigator.pop(ctx, 'delete'),
                                      ),
                                      ListTile(
                                        title: Text(loc.translate('cancel')),
                                        onTap: () => Navigator.pop(ctx, null),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );

                            if (!context.mounted) return;

                            if (choice == 'open') {
                              Navigator.pop(context);
                              Provider.of<ChatProvider>(
                                context,
                                listen: false,
                              ).loadConversation(conv.id);
                            } else if (choice == 'save') {
                              await Provider.of<ChatProvider>(
                                context,
                                listen: false,
                              ).saveConversation(conv.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc.translate('conversation_saved'),
                                  ),
                                ),
                              );
                            } else if (choice == 'share') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc.translate('share_not_implemented'),
                                  ),
                                ),
                              );
                            } else if (choice == 'delete') {
                              await Provider.of<ChatProvider>(
                                context,
                                listen: false,
                              ).deleteConversation(conv.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc.translate('conversation_deleted'),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      }).toList(),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatProvider.messages.isEmpty && !isTyping
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 80.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(
                                alpha: 25 / 255,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.smart_toy,
                              size: 40,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            loc.translate('chat_greeting'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.translate('chat_intro'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount:
                        chatProvider.messages.length + (isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chatProvider.messages.length && isTyping) {
                        return _buildTypingIndicator(context);
                      }
                      final msg = chatProvider.messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),
          // SafeArea keeps the input above Android system navigation buttons.
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(0, 0, 0, 0.1),
                    offset: const Offset(0, -2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[850]?.withValues(alpha: 128 / 255)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]!.withValues(alpha: 102 / 255)
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(0, 0, 0, 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          hintText: loc.translate('chat_hint'),
                          hintStyle: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color
                                ?.withValues(alpha: 128 / 255),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) {
                          final provider = Provider.of<ChatProvider>(
                            context,
                            listen: false,
                          );
                          if (!provider.isLoading) _sendMessage();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.redAccent, Colors.pinkAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 77 / 255),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: isTyping ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE8F5E8),
            child: Icon(Icons.smart_toy, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  loc.translate('typing'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(width: 8),
                const SizedBox(width: 24, height: 14, child: _BouncingDots()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              backgroundColor: Color(0xFFE8F5E8),
              child: Icon(Icons.smart_toy, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? Colors.redAccent : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use MarkdownBody for better formatting
                  MarkdownBody(
                    data: msg.text,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      h1: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      h2: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      h3: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      strong: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      em: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      listIndent: 24,
                      blockSpacing: 12,
                      listBulletPadding: const EdgeInsets.only(right: 8),
                      pPadding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    selectable: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(msg.timestamp),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                  if (msg.relatedPlaces != null &&
                      msg.relatedPlaces!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: ChatPlacesCarousel(places: msg.relatedPlaces!),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        double v(int i) =>
            (1 +
                (0.6 *
                    (1 + math.sin(2 * 3.1415926 * (_c.value + (i * 0.15)))))) /
            2;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) {
            final scale = 0.6 + 0.4 * v(i);
            return Transform.translate(
              offset: Offset(0, -3 * v(i)),
              child: Container(
                width: 4 * scale,
                height: 4 * scale,
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class ChatPlacesCarousel extends StatefulWidget {
  const ChatPlacesCarousel({super.key, required this.places});

  final List places;

  @override
  State<ChatPlacesCarousel> createState() => _ChatPlacesCarouselState();
}

class _ChatPlacesCarouselState extends State<ChatPlacesCarousel> {
  final ScrollController _controller = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  double get _step => 240.0;

  void _scrollTo(double offset) {
    final max = _controller.hasClients
        ? _controller.position.maxScrollExtent
        : 0.0;
    final target = offset.clamp(0.0, max);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_updateNavVisibility);
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateNavVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateNavVisibility());
  }

  void _updateNavVisibility() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final off = _controller.offset;
    final canLeft = off > 8.0;
    final canRight = off < (max - 8.0);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: widget.places.length,
            itemBuilder: (context, index) =>
                PlaceCard(place: widget.places[index]),
          ),
          if (kIsWeb) ...[
            Positioned(
              left: 4,
              child: IgnorePointer(
                ignoring: !_canScrollLeft,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _canScrollLeft ? 1.0 : 0.0,
                  child: _ChatNavButton(
                    icon: Icons.chevron_left,
                    onTap: () => _scrollTo(_controller.offset - _step),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              child: IgnorePointer(
                ignoring: !_canScrollRight,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _canScrollRight ? 1.0 : 0.0,
                  child: _ChatNavButton(
                    icon: Icons.chevron_right,
                    onTap: () => _scrollTo(_controller.offset + _step),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatNavButton extends StatelessWidget {
  // ignore: unused_element_parameter
  const _ChatNavButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 40 / 255),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
