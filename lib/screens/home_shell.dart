import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/notification_service.dart';
import '../theme/app_palette.dart';
import '../theme/theme_provider.dart';
import '../widgets/common.dart';
import '../widgets/user_avatar.dart';
import 'chats_screen.dart';
import 'people_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Main screen after login: tabs + floating dark navigation bar with a
/// central "+" button (new chat).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final uid = ref.read(currentUidProvider)!;
    final notifications = NotificationService.instance;
    notifications.onOpenChat = (chatId) {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      setState(() => _index = 0);
      openChat(context, chatId);
    };
    ref.read(chatServiceProvider).ensureGlobalMembership(uid).ignore();
    notifications.start(
      uid: uid,
      chats: ref.read(chatServiceProvider).chatsFor(uid),
      userService: ref.read(userServiceProvider),
      users: () => ref.read(usersProvider).value ?? const {},
      enabled: () => ref.read(notificationsEnabledProvider),
    );
  }

  @override
  void dispose() {
    NotificationService.instance.onOpenChat = null;
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the users stream alive app-wide (avatars, names, presence).
    ref.watch(usersProvider);
    final uid = ref.watch(currentUidProvider);
    final tabs = <Widget>[
      const ChatsScreen(),
      const PeopleScreen(),
      if (uid != null) _MyProfileTab(uid: uid) else const SizedBox(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: AppBackground(
        child: Stack(
          children: [
            for (var i = 0; i < tabs.length; i++)
              IgnorePointer(
                ignoring: i != _index,
                child: HeroMode(
                  enabled: i == _index,
                  child: AnimatedOpacity(
                    opacity: i == _index ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: AnimatedSlide(
                      offset: i == _index ? Offset.zero : const Offset(0, 0.02),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: TickerMode(enabled: i == _index, child: tabs[i]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _FloatingNavBar(
        index: _index,
        onSelect: _select,
        onAdd: () => showNewChatSheet(context, ref),
      ),
    );
  }
}

class _MyProfileTab extends StatelessWidget {
  const _MyProfileTab({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    // Re-use the profile layout without the back button stack.
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
    );
  }
}

class _FloatingNavBar extends ConsumerWidget {
  const _FloatingNavBar({required this.index, required this.onSelect, required this.onAdd});

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final me = ref.watch(currentUidProvider);
    final chats = ref.watch(myChatsProvider).value ?? const [];
    final unread = me == null ? 0 : chats.where((c) => c.unreadFor(me) > 0).length;

    Widget item(int i, IconData icon, IconData active, String label, {Widget? badge}) {
      final selected = i == index;
      return Expanded(
        child: Semantics(
          label: label,
          selected: selected,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? palette.navSelected.withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                        child: Icon(
                          selected ? active : icon,
                          key: ValueKey(selected),
                          color: selected ? palette.navSelected : Colors.white70,
                          size: 24,
                        ),
                      ),
                    ),
                    if (badge != null) Positioned(right: 4, top: -4, child: badge),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? palette.navSelected : Colors.white60,
                    fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 84,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 70,
                decoration: BoxDecoration(
                  color: palette.navBar,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    item(0, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chats',
                        badge: unread > 0 ? CountBadge(count: unread, color: palette.navBadge) : null),
                    item(1, Icons.people_outline_rounded, Icons.people_rounded, 'People'),
                    const SizedBox(width: 72),
                    item(2, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
                    item(3, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [palette.spec.secondary, palette.spec.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: palette.navBar, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: palette.spec.primary.withValues(alpha: 0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small helper so other files can show "my" avatar without importing shell.
class MyAvatar extends ConsumerWidget {
  const MyAvatar({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return SizedBox(width: size, height: size);
    return UserAvatar(uid: uid, size: size);
  }
}
