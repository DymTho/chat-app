import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/providers.dart';
import '../theme/app_palette.dart';
import '../widgets/common.dart';
import '../widgets/user_avatar.dart';
import 'chats_screen.dart';
import 'profile_screen.dart';

/// Directory of all registered users.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUidProvider);
    final users = ref.watch(usersProvider);
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
            child: Text('People',
                style: theme.textTheme.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search people…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                  icon: Icons.error_outline, title: 'Could not load people', subtitle: '$e'),
              data: (map) {
                final list = map.values
                    .where((u) => u.uid != me)
                    .where((u) =>
                        _query.isEmpty ||
                        u.username.toLowerCase().contains(_query) ||
                        u.email.toLowerCase().contains(_query))
                    .toList()
                  ..sort((a, b) {
                    if (a.online != b.online) return a.online ? -1 : 1;
                    return a.username.toLowerCase().compareTo(b.username.toLowerCase());
                  });
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No one here yet',
                    subtitle: 'Invite a friend to register and they will show up here.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 120),
                  itemCount: list.length,
                  itemBuilder: (context, i) => PersonTile(user: list[i])
                      .animate()
                      .fadeIn(delay: (35 * i).clamp(0, 350).ms)
                      .slideY(begin: 0.15, end: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PersonTile extends ConsumerWidget {
  const PersonTile({super.key, required this.user, this.onTap});

  final AppUser user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: UserAvatar(uid: user.uid, size: 50, showOnline: true, heroTag: 'profile-${user.uid}'),
      title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        user.online ? 'online' : formatLastSeen(user.lastSeen),
        style: TextStyle(
          fontSize: 12,
          color: user.online ? palette.online : palette.muted,
        ),
      ),
      trailing: IconButton.filledTonal(
        style: IconButton.styleFrom(
          backgroundColor: palette.spec.primary.withValues(alpha: 0.12),
          foregroundColor: palette.spec.primary,
        ),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
        onPressed: () => openDirectChat(context, ref, user.uid),
      ),
      onTap: onTap ??
          () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid))),
    );
  }
}

/// Bottom sheet opened from the "+" button to start a new conversation.
Future<void> showNewChatSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Consumer(
        builder: (ctx, ref, _) {
          final me = ref.watch(currentUidProvider);
          final users = (ref.watch(usersProvider).value ?? const {})
              .values
              .where((u) => u.uid != me)
              .toList()
            ..sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
          return Column(
            children: [
              Text('New chat',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: users.isEmpty
                    ? const EmptyState(
                        icon: Icons.person_search_rounded,
                        title: 'No other users yet',
                        subtitle: 'Register a second account to start chatting.',
                      )
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: users.length,
                        itemBuilder: (_, i) => PersonTile(
                          user: users[i],
                          onTap: () {
                            Navigator.pop(ctx);
                            openDirectChat(context, ref, users[i].uid);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
