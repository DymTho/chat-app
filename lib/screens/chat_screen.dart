import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../providers/providers.dart';
import '../services/notification_service.dart';
import '../theme/app_palette.dart';
import '../widgets/common.dart';
import '../widgets/message_bubble.dart';
import '../widgets/user_avatar.dart';
import 'profile_screen.dart';

const reactionEmojis = ['🔥', '🙌', '❤️', '😂', '😮', '😡', '👍'];

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _focus = FocusNode();
  final _scrollCtrl = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showEmojis = false;
  Message? _replyTo;
  Message? _editing;
  late final String _me;
  late final DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _me = ref.read(currentUidProvider)!;
    _openedAt = DateTime.now();
    NotificationService.instance.activeChatId = widget.chatId;
    NotificationService.instance.clearChat(widget.chatId);
    ref.read(chatServiceProvider).markRead(widget.chatId, _me);
    _textCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (NotificationService.instance.activeChatId == widget.chatId) {
      NotificationService.instance.activeChatId = null;
    }
    _typingTimer?.cancel();
    if (_isTyping) {
      ref.read(chatServiceProvider).setTyping(widget.chatId, _me, false);
    }
    _textCtrl.dispose();
    _focus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    final service = ref.read(chatServiceProvider);
    if (!_isTyping) {
      _isTyping = true;
      service.setTyping(widget.chatId, _me, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      service.setTyping(widget.chatId, _me, false);
    });
  }

  Future<void> _send(Chat chat) async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final service = ref.read(chatServiceProvider);
    final me = ref.read(currentUserProvider);
    HapticFeedback.lightImpact();

    final editing = _editing;
    final reply = _replyTo;
    _textCtrl.clear();
    setState(() {
      _replyTo = null;
      _editing = null;
    });
    _typingTimer?.cancel();
    _isTyping = false;

    try {
      if (editing != null) {
        await service.editMessage(chat.id, editing.id, text);
      } else {
        final future = service.sendMessage(
          chat: chat,
          senderId: _me,
          senderName: me?.username ?? 'Unknown',
          text: text,
          replyTo: reply == null
              ? null
              : ReplyRef(
                  id: reply.id,
                  text: reply.text,
                  senderName: reply.senderName,
                ),
        );
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(0,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
        await future;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send message: $e')));
      }
    }
  }

  void _startReply(Message m) {
    setState(() {
      _editing = null;
      _replyTo = m;
    });
    _focus.requestFocus();
  }

  void _startEdit(Message m) {
    setState(() {
      _replyTo = null;
      _editing = m;
      _textCtrl.text = m.text;
      _textCtrl.selection = TextSelection.collapsed(offset: m.text.length);
    });
    _focus.requestFocus();
  }

  Future<void> _showMessageActions(Message m, bool isMine) async {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    final service = ref.read(chatServiceProvider);
    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Message actions',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, _) => _MessageActionsSheet(message: m, isMine: isMine, me: _me),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8 * anim.value, sigmaY: 8 * anim.value),
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    if (action.startsWith('react:')) {
      service.toggleReaction(
        chatId: widget.chatId,
        message: m,
        uid: _me,
        emoji: action.substring(6),
      );
    } else if (action == 'reply') {
      _startReply(m);
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.text));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Message copied')));
      }
    } else if (action == 'edit') {
      _startEdit(m);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete message?'),
          content: const Text('This message will be deleted for everyone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) service.deleteMessage(widget.chatId, m.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the unread counter at zero while the chat is open.
    ref.listen(chatProvider(widget.chatId), (_, next) {
      final chat = next.value;
      if (chat != null && chat.unreadFor(_me) > 0) {
        ref.read(chatServiceProvider).markRead(widget.chatId, _me);
      }
    });

    final chat = ref.watch(chatProvider(widget.chatId)).value;
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final users = ref.watch(usersProvider).value ?? const {};
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.header,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _ChatHeader(chatId: widget.chatId, chat: chat, me: _me, users: users),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              clipBehavior: Clip.antiAlias,
              child: AppBackground(
                child: Column(
                  children: [
                    Expanded(
                      child: messagesAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Could not load messages',
                          subtitle: '$e',
                        ),
                        data: (messages) => messages.isEmpty
                            ? const EmptyState(
                                icon: Icons.waving_hand_rounded,
                                title: 'No messages yet',
                                subtitle: 'Send the first message to start the conversation.',
                              )
                            : _buildMessageList(messages, users),
                      ),
                    ),
                    if (chat != null) _buildTypingRow(chat, users),
                    if (chat != null) _buildComposer(chat),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages, Map<String, AppUser> users) {
    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        // List is newest-first: "previous" in time is i+1, "next" is i-1.
        final older = i + 1 < messages.length ? messages[i + 1] : null;
        final newer = i > 0 ? messages[i - 1] : null;
        final mine = m.senderId == _me;
        final time = m.createdAt ?? DateTime.now();
        final olderTime = older?.createdAt ?? DateTime.now();

        final newDay = older == null ||
            DateTime(time.year, time.month, time.day) !=
                DateTime(olderTime.year, olderTime.month, olderTime.day);
        final first = newDay ||
            older.senderId != m.senderId ||
            time.difference(olderTime).inMinutes > 5;
        final newerTime = newer?.createdAt ?? DateTime.now();
        final last = newer == null ||
            newer.senderId != m.senderId ||
            newerTime.difference(time).inMinutes > 5;

        final bubble = MessageBubble(
          key: ValueKey(m.id),
          message: m,
          isMine: mine,
          isFirstInGroup: first,
          isLastInGroup: last,
          myUid: _me,
          senderName: users[m.senderId]?.username ?? m.senderName,
          animate: m.isPending || (m.createdAt?.isAfter(_openedAt) ?? false),
          onLongPress: m.deleted ? null : () => _showMessageActions(m, mine),
          onReply: () => _startReply(m),
          onReactionTap: (emoji) => ref.read(chatServiceProvider).toggleReaction(
                chatId: widget.chatId,
                message: m,
                uid: _me,
                emoji: emoji,
              ),
        );

        if (!newDay) return bubble;
        return Column(
          children: [
            _DayChip(label: formatDayHeader(time)),
            bubble,
          ],
        );
      },
    );
  }

  Widget _buildTypingRow(Chat chat, Map<String, AppUser> users) {
    final typing = chat.typingUsers(_me);
    final palette = context.palette;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: typing.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Row(
                children: [
                  UserAvatar(uid: typing.first, size: 22),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: palette.bubbleOther,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const TypingIndicator(),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      chat.isGroup
                          ? '${typing.map((u) => users[u]?.username.split(' ').first ?? '…').join(', ')} typing'
                          : '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms),
    );
  }

  Widget _buildComposer(Chat chat) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final hasText = _textCtrl.text.trim().isNotEmpty;
    final banner = _editing ?? _replyTo;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: banner == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                      decoration: BoxDecoration(
                        color: palette.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border(
                            left: BorderSide(color: palette.spec.primary, width: 4)),
                      ),
                      child: Row(
                        children: [
                          Icon(_editing != null ? Icons.edit_rounded : Icons.reply_rounded,
                              color: palette.spec.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _editing != null
                                      ? 'Edit message'
                                      : 'Reply to ${banner.senderId == _me ? 'yourself' : banner.senderName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: palette.spec.primary,
                                  ),
                                ),
                                Text(banner.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: palette.muted)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => setState(() {
                              if (_editing != null) _textCtrl.clear();
                              _replyTo = null;
                              _editing = null;
                            }),
                          ),
                        ],
                      ),
                    ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: !_showEmojis
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      height: 48,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: palette.card,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final e in const [
                            '😀', '😂', '🥰', '😎', '🤔', '😭', '👍', '🙏',
                            '🔥', '🎉', '❤️', '💯', '👋', '✨', '🙌', '😅',
                          ])
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                final sel = _textCtrl.selection;
                                final text = _textCtrl.text;
                                final start = sel.isValid ? sel.start : text.length;
                                final end = sel.isValid ? sel.end : text.length;
                                _textCtrl.value = TextEditingValue(
                                  text: text.replaceRange(start, end, e),
                                  selection: TextSelection.collapsed(offset: start + e.length),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(e, style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: palette.softShadow,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => setState(() => _showEmojis = !_showEmojis),
                          icon: Icon(
                            _showEmojis
                                ? Icons.keyboard_rounded
                                : Icons.sentiment_satisfied_alt_rounded,
                            color: palette.muted,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            focusNode: _focus,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: _onTextChanged,
                            style: theme.textTheme.bodyMedium,
                            decoration: const InputDecoration(
                              hintText: 'Message…',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedScale(
                  scale: hasText ? 1 : 0.85,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: hasText
                            ? [palette.spec.secondary, palette.spec.primary]
                            : [palette.muted.withValues(alpha: 0.4), palette.muted.withValues(alpha: 0.5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: hasText
                          ? [
                              BoxShadow(
                                color: palette.spec.primary.withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: hasText ? () => _send(chat) : null,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (c, a) => RotationTransition(
                            turns: Tween(begin: 0.75, end: 1.0).animate(a),
                            child: ScaleTransition(scale: a, child: c),
                          ),
                          child: Icon(
                            _editing != null ? Icons.check_rounded : Icons.send_rounded,
                            key: ValueKey(_editing != null),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({
    required this.chatId,
    required this.chat,
    required this.me,
    required this.users,
  });

  final String chatId;
  final Chat? chat;
  final String me;
  final Map<String, AppUser> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final chat = this.chat;
    final otherUid = chat?.otherMember(me);
    final other = otherUid == null ? null : users[otherUid];
    final title = chat == null ? '' : chatTitle(chat, me, users);
    final typing = chat?.typingUsers(me) ?? const [];

    String subtitle;
    if (typing.isNotEmpty) {
      subtitle = chat!.isGroup
          ? '${users[typing.first]?.username.split(' ').first ?? 'Someone'} is typing…'
          : 'typing…';
    } else if (chat?.isGroup ?? false) {
      final online = chat!.members.where((m) => users[m]?.online ?? false).length;
      subtitle = '${chat.members.length} members · $online online';
    } else if (other?.online ?? false) {
      subtitle = 'online';
    } else {
      subtitle = formatLastSeen(other?.lastSeen);
    }

    final meUser = ref.watch(currentUserProvider);
    final pinned = meUser?.pinnedChats.contains(chatId) ?? false;
    final favourite = meUser?.favouriteChats.contains(chatId) ?? false;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 16),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: chat == null
                    ? null
                    : () {
                        if (chat.isGroup) {
                          _showMembers(context, chat);
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ProfileScreen(uid: otherUid!),
                          ));
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      if (chat?.isGroup ?? false)
                        GroupAvatar(size: 46, heroTag: 'avatar-$chatId')
                      else if (otherUid != null)
                        UserAvatar(
                            uid: otherUid, size: 46, showOnline: true, heroTag: 'avatar-$chatId'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Row(
                                key: ValueKey(subtitle),
                                children: [
                                  if (typing.isNotEmpty) ...[
                                    TypingIndicator(color: palette.headerAccent),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: typing.isNotEmpty || subtitle == 'online'
                                            ? palette.headerAccent
                                            : Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (v) {
                final service = ref.read(userServiceProvider);
                switch (v) {
                  case 'pin':
                    service.setPinned(me, chatId, !pinned);
                  case 'fav':
                    service.setFavourite(me, chatId, !favourite);
                  case 'members':
                    if (chat != null) _showMembers(context, chat);
                  case 'profile':
                    if (otherUid != null) {
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ProfileScreen(uid: otherUid)));
                    }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'pin', child: Text(pinned ? 'Unpin chat' : 'Pin chat')),
                PopupMenuItem(
                    value: 'fav',
                    child: Text(favourite ? 'Remove from favourites' : 'Add to favourites')),
                if (chat?.isGroup ?? false)
                  const PopupMenuItem(value: 'members', child: Text('Members'))
                else
                  const PopupMenuItem(value: 'profile', child: Text('View profile')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMembers(BuildContext context, Chat chat) {
    final members = chat.members.map((m) => users[m]).whereType<AppUser>().toList()
      ..sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        return a.username.compareTo(b.username);
      });
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => Column(
          children: [
            Text('${chat.name ?? 'Group'} · ${members.length} members',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: members.length,
                itemBuilder: (ctx, i) {
                  final u = members[i];
                  return ListTile(
                    leading: UserAvatar(uid: u.uid, size: 44, showOnline: true),
                    title: Text(u.uid == me ? '${u.username} (you)' : u.username),
                    subtitle: Text(u.online ? 'online' : formatLastSeen(u.lastSeen)),
                    onTap: u.uid == me
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ProfileScreen(uid: u.uid)));
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: palette.bubbleOther,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, color: palette.muted, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

/// Bottom card with the message preview, a reaction bar and actions —
/// inspired by the "React / Reply / Copy / Delete" sheet in the mock-up.
class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet({required this.message, required this.isMine, required this.me});

  final Message message;
  final bool isMine;
  final String me;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;

    Widget action(String value, String label, IconData icon, {Color? color}) => InkWell(
          onTap: () => Navigator.pop(context, value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w500, fontSize: 15)),
                ),
                Icon(icon, color: color ?? palette.muted, size: 22),
              ],
            ),
          ),
        );

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMine ? palette.bubbleMine : palette.bubbleOther,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      message.text,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMine ? palette.onBubbleMine : palette.onBubbleOther,
                      ),
                    ),
                  ).animate().scale(
                      begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack, duration: 300.ms),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                          child: Text('React',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, color: palette.muted, fontSize: 13)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              for (var i = 0; i < reactionEmojis.length; i++)
                                GestureDetector(
                                  onTap: () => Navigator.pop(context, 'react:${reactionEmojis[i]}'),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: message.reactions[me] == reactionEmojis[i]
                                          ? palette.spec.primary.withValues(alpha: 0.18)
                                          : null,
                                    ),
                                    child: Text(reactionEmojis[i],
                                        style: const TextStyle(fontSize: 26)),
                                  ),
                                )
                                    .animate()
                                    .fadeIn(delay: (40 * i).ms)
                                    .scale(
                                        begin: const Offset(0.3, 0.3),
                                        delay: (40 * i).ms,
                                        curve: Curves.easeOutBack),
                            ],
                          ),
                        ),
                        const Divider(),
                        action('reply', 'Reply', Icons.reply_rounded),
                        action('copy', 'Copy', Icons.copy_rounded),
                        if (isMine) action('edit', 'Edit', Icons.edit_outlined),
                        if (isMine)
                          action('delete', 'Delete', Icons.delete_outline_rounded, color: error),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
