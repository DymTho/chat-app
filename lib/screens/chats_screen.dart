import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/chat.dart';
import '../providers/providers.dart';
import '../theme/app_palette.dart';
import '../widgets/common.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

enum ChatFilter { all, unread, favourites, groups }

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  ChatFilter _filter = ChatFilter.all;
  bool _searching = false;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUidProvider);
    final meUser = ref.watch(currentUserProvider);
    final users = ref.watch(usersProvider).value ?? const {};
    final chatsAsync = ref.watch(myChatsProvider);
    final theme = Theme.of(context);

    if (me == null) return const SizedBox.shrink();

    final allChats = (chatsAsync.value ?? const <Chat>[])
        .where((c) => c.isGroup || c.lastMessage.isNotEmpty)
        .toList();
    final pinnedIds = meUser?.pinnedChats ?? const [];
    final favIds = meUser?.favouriteChats ?? const [];
    final unreadTotal = allChats.where((c) => c.unreadFor(me) > 0).length;

    final filtered = allChats.where((c) {
      switch (_filter) {
        case ChatFilter.all:
          break;
        case ChatFilter.unread:
          if (c.unreadFor(me) == 0) return false;
        case ChatFilter.favourites:
          if (!favIds.contains(c.id)) return false;
        case ChatFilter.groups:
          if (!c.isGroup) return false;
      }
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return chatTitle(c, me, users).toLowerCase().contains(q) ||
          c.lastMessage.toLowerCase().contains(q);
    }).toList();

    final pinned = filtered.where((c) => pinnedIds.contains(c.id)).toList();
    final others = filtered.where((c) => !pinnedIds.contains(c.id)).toList();

    final onlineUsers = users.values.where((u) => u.online && u.uid != me).toList()
      ..sort((a, b) => a.username.compareTo(b.username));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chats',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  _RoundIconButton(
                    icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                    onTap: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) {
                        _query = '';
                        _searchCtrl.clear();
                      }
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _searching
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: const InputDecoration(
                        hintText: 'Search chats or messages…',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
        SliverToBoxAdapter(
          child: _OnlineRow(me: me, onlineUsers: onlineUsers),
        ),
        SliverToBoxAdapter(
          child: _FilterBar(
            value: _filter,
            unread: unreadTotal,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ),
        if (chatsAsync.isLoading && allChats.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: _filter == ChatFilter.favourites
                  ? Icons.star_outline_rounded
                  : Icons.forum_outlined,
              title: _query.isNotEmpty
                  ? 'Nothing found'
                  : switch (_filter) {
                      ChatFilter.unread => 'All caught up!',
                      ChatFilter.favourites => 'No favourites yet',
                      ChatFilter.groups => 'No groups',
                      ChatFilter.all => 'No chats yet',
                    },
              subtitle: _filter == ChatFilter.favourites
                  ? 'Long-press a chat to add it to favourites.'
                  : 'Tap + to start a new conversation.',
            ),
          )
        else ...[
          if (pinned.isNotEmpty) ...[
            _SectionHeader(icon: Icons.push_pin_rounded, title: 'Pinned', count: pinned.length),
            _ChatList(chats: pinned, me: me, pinned: pinnedIds, favourites: favIds),
          ],
          if (others.isNotEmpty) ...[
            if (pinned.isNotEmpty)
              _SectionHeader(icon: Icons.chat_rounded, title: 'All chats', count: others.length),
            _ChatList(chats: others, me: me, pinned: pinnedIds, favourites: favIds),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.card,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: palette.softShadow),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => RotationTransition(turns: a, child: c),
            child: Icon(icon, key: ValueKey(icon)),
          ),
        ),
      ),
    );
  }
}

class _OnlineRow extends ConsumerWidget {
  const _OnlineRow({required this.me, required this.onlineUsers});

  final String me;
  final List<AppUser> onlineUsers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Text('Online now',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  CountBadge(count: onlineUsers.length, color: palette.online),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 86,
              child: onlineUsers.isEmpty
                  ? Center(
                      child: Text('Nobody else is online right now',
                          style: TextStyle(color: palette.muted, fontSize: 13)),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: onlineUsers.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, i) {
                        final u = onlineUsers[i];
                        return GestureDetector(
                          onTap: () => openDirectChat(context, ref, u.uid),
                          child: SizedBox(
                            width: 64,
                            child: Column(
                              children: [
                                UserAvatar(uid: u.uid, size: 54, ring: true, showOnline: true),
                                const SizedBox(height: 6),
                                Text(
                                  u.username.split(' ').first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: (60 * i).ms)
                            .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.unread, required this.onChanged});

  final ChatFilter value;
  final int unread;
  final ValueChanged<ChatFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const labels = {
      ChatFilter.all: 'All',
      ChatFilter.unread: 'Unread',
      ChatFilter.favourites: 'Favourites',
      ChatFilter.groups: 'Groups',
    };
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        children: [
          for (final f in ChatFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == f ? palette.spec.primary : palette.card,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: value == f
                        ? [
                            BoxShadow(
                              color: palette.spec.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      if (f == ChatFilter.all && value == f) ...[
                        const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        labels[f]!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: value == f ? Colors.white : null,
                        ),
                      ),
                      if (f == ChatFilter.unread && unread > 0) ...[
                        const SizedBox(width: 6),
                        CountBadge(
                          count: unread,
                          color: value == f ? Colors.white.withValues(alpha: 0.3) : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, required this.count});

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 2),
        child: Row(
          children: [
            Icon(icon, size: 16, color: palette.muted),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, color: palette.muted)),
            const SizedBox(width: 6),
            CountBadge(count: count, color: palette.muted.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({
    required this.chats,
    required this.me,
    required this.pinned,
    required this.favourites,
  });

  final List<Chat> chats;
  final String me;
  final List<String> pinned;
  final List<String> favourites;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      sliver: SliverList.builder(
        itemCount: chats.length,
        itemBuilder: (context, i) => ChatTile(
          key: ValueKey(chats[i].id),
          chat: chats[i],
          me: me,
          pinned: pinned.contains(chats[i].id),
          favourite: favourites.contains(chats[i].id),
        )
            .animate()
            .fadeIn(delay: (40 * i).clamp(0, 400).ms, duration: 300.ms)
            .slideX(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class ChatTile extends ConsumerWidget {
  const ChatTile({
    super.key,
    required this.chat,
    required this.me,
    required this.pinned,
    required this.favourite,
  });

  final Chat chat;
  final String me;
  final bool pinned;
  final bool favourite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider).value ?? const {};
    final palette = context.palette;
    final title = chatTitle(chat, me, users);
    final unread = chat.unreadFor(me);
    final typing = chat.typingUsers(me);
    final other = chat.otherMember(me);

    String preview;
    if (typing.isNotEmpty) {
      preview = chat.isGroup
          ? '${users[typing.first]?.username.split(' ').first ?? 'Someone'} is typing…'
          : 'typing…';
    } else if (chat.lastMessage.isEmpty) {
      preview = 'Say hi 👋';
    } else if (chat.lastSenderId == me) {
      preview = 'You: ${chat.lastMessage}';
    } else if (chat.isGroup && chat.lastSenderId != null) {
      final name = users[chat.lastSenderId]?.username.split(' ').first ?? '';
      preview = name.isEmpty ? chat.lastMessage : '$name: ${chat.lastMessage}';
    } else {
      preview = chat.lastMessage;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => openChat(context, chat.id),
      onLongPress: () => _showActions(context, ref, title),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            chat.isGroup
                ? GroupAvatar(size: 54, heroTag: 'avatar-${chat.id}')
                : UserAvatar(
                    uid: other!, size: 54, showOnline: true, heroTag: 'avatar-${chat.id}'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      if (favourite) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB800)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      preview,
                      key: ValueKey(preview),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: typing.isNotEmpty
                            ? palette.spec.primary
                            : unread > 0
                                ? Theme.of(context).colorScheme.onSurface
                                : palette.muted,
                        fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
                        fontStyle: typing.isNotEmpty ? FontStyle.italic : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatChatTime(chat.updatedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: unread > 0 ? palette.spec.primary : palette.muted,
                    fontWeight: unread > 0 ? FontWeight.w600 : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.push_pin_rounded, size: 15, color: palette.muted),
                      ),
                    if (unread > 0)
                      CountBadge(count: unread)
                    else if (chat.lastSenderId == me)
                      Icon(Icons.done_all_rounded, size: 17, color: palette.spec.primary)
                    else
                      const SizedBox(height: 22),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, String title) {
    final userService = ref.read(userServiceProvider);
    final chatService = ref.read(chatServiceProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
              title: Text(pinned ? 'Unpin chat' : 'Pin chat'),
              onTap: () {
                Navigator.pop(ctx);
                userService.setPinned(me, chat.id, !pinned);
              },
            ),
            ListTile(
              leading: Icon(favourite ? Icons.star_outline_rounded : Icons.star_rounded),
              title: Text(favourite ? 'Remove from favourites' : 'Add to favourites'),
              onTap: () {
                Navigator.pop(ctx);
                userService.setFavourite(me, chat.id, !favourite);
              },
            ),
            if (chat.unreadFor(me) > 0)
              ListTile(
                leading: const Icon(Icons.mark_chat_read_outlined),
                title: const Text('Mark as read'),
                onTap: () {
                  Navigator.pop(ctx);
                  chatService.markRead(chat.id, me);
                },
              ),
            if (!chat.isGroup)
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('View profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(uid: chat.otherMember(me)!),
                  ));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

void openChat(BuildContext context, String chatId) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
}

Future<void> openDirectChat(BuildContext context, WidgetRef ref, String otherUid) async {
  final me = ref.read(currentUidProvider);
  if (me == null || otherUid == me) return;
  final id = await ref.read(chatServiceProvider).openDirectChat(me, otherUid);
  if (context.mounted) openChat(context, id);
}
