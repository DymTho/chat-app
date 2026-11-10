import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/chat.dart';
import '../providers/providers.dart';
import '../theme/app_palette.dart';
import '../widgets/common.dart';
import '../widgets/user_avatar.dart';
import 'chats_screen.dart';

/// Profile of another user (gradient cover, big avatar, actions).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(usersProvider).value?[uid];
    final me = ref.watch(currentUidProvider);
    final chats = ref.watch(myChatsProvider).value ?? const <Chat>[];
    final palette = context.palette;
    final theme = Theme.of(context);
    final isMe = uid == me;
    final directId = me == null ? null : Chat.directId(me, uid);
    final direct = chats.where((c) => c.id == directId).firstOrNull;
    final sharedGroups = chats.where((c) => c.isGroup && c.members.contains(uid)).toList();

    return Scaffold(
      body: AppBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 310,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 230,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [palette.header, palette.spec.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                      ),
                    ),
                    if (Navigator.of(context).canPop())
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 150,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: UserAvatar(
                            uid: uid,
                            size: 140,
                            showOnline: true,
                            heroTag: 'profile-$uid',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Text(
                    user?.username ?? '',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user == null
                        ? ''
                        : user.online
                            ? '● online'
                            : formatLastSeen(user.lastSeen),
                    style: TextStyle(color: user?.online == true ? palette.online : palette.muted),
                  ),
                  if ((user?.bio ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(user!.bio, textAlign: TextAlign.center),
                    ),
                  ],
                ],
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.2, end: 0),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
              sliver: SliverList.list(
                children: [
                  if (!isMe)
                    FilledButton.icon(
                      onPressed: () => openDirectChat(context, ref, uid),
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: const Text('Send message'),
                    ),
                  const SizedBox(height: 18),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'Email',
                          value: user?.email ?? '',
                        ),
                        _InfoRow(
                          icon: Icons.calendar_month_rounded,
                          label: 'Member since',
                          value: user?.createdAt == null
                              ? '—'
                              : DateFormat.yMMMMd().format(user!.createdAt!),
                        ),
                        if (!isMe)
                          _InfoRow(
                            icon: Icons.forum_rounded,
                            label: 'Last message',
                            value: (direct?.lastMessage.isNotEmpty ?? false)
                                ? direct!.lastMessage
                                : 'No messages yet',
                          ),
                        _InfoRow(
                          icon: Icons.groups_rounded,
                          label: 'Groups in common',
                          value: sharedGroups.isEmpty
                              ? 'None'
                              : sharedGroups.map((g) => g.name ?? 'Group').join(', '),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: palette.spec.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: palette.spec.primary, size: 20),
      ),
      title: Text(label, style: TextStyle(fontSize: 12, color: palette.muted)),
      subtitle: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
