import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/notification_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/common.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/user_avatar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final uid = ref.watch(currentUidProvider);
    final themeSettings = ref.watch(themeControllerProvider);
    final notificationsOn = ref.watch(notificationsEnabledProvider);
    final palette = context.palette;
    final theme = Theme.of(context);

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
          child: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: palette.muted, fontSize: 13)),
        );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 130),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('Settings',
                style: theme.textTheme.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1)),
          ),
          const SizedBox(height: 16),
          if (uid != null)
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _changeAvatar(context, ref, uid),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UserAvatar(uid: uid, size: 72, heroTag: 'profile-$uid'),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: palette.spec.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: palette.card, width: 3),
                            ),
                            child: const Icon(Icons.photo_camera_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me?.username ?? '',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text(me?.email ?? '',
                            style: TextStyle(color: palette.muted, fontSize: 13)),
                        if ((me?.bio ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(me!.bio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _editProfile(context, ref, uid),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          section('THEME'),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: PaletteSpec.all.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final spec = PaletteSpec.all[i];
                return _ThemePreview(
                  spec: spec,
                  brightness: theme.brightness,
                  selected: themeSettings.palette == spec.id,
                  onTap: () =>
                      ref.read(themeControllerProvider.notifier).setPalette(spec.id),
                ).animate().fadeIn(delay: (70 * i).ms).slideX(begin: 0.2, end: 0);
              },
            ),
          ),
          section('APPEARANCE'),
          SegmentedButton<ThemeMode>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: palette.spec.primary,
              selectedForegroundColor: Colors.white,
              backgroundColor: palette.card,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              minimumSize: const Size.fromHeight(50),
            ),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Light')),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Dark')),
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('System')),
            ],
            selected: {themeSettings.mode},
            onSelectionChanged: (s) =>
                ref.read(themeControllerProvider.notifier).setMode(s.first),
          ),
          section('NOTIFICATIONS'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: notificationsOn,
                  onChanged: (v) => ref.read(notificationsEnabledProvider.notifier).set(v),
                  secondary: _IconBox(icon: Icons.notifications_active_rounded),
                  title: const Text('Message notifications'),
                  subtitle: Text('Show a notification when a new message arrives',
                      style: TextStyle(fontSize: 12, color: palette.muted)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ],
            ),
          ),
          section('ACCOUNT'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: _IconBox(icon: Icons.logout_rounded, color: theme.colorScheme.error),
              title: Text('Log out',
                  style: TextStyle(
                      color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              onTap: () => _logout(context, ref),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('Chatloop · Assignment 6 · Flutter + Firebase',
                style: TextStyle(color: palette.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _changeAvatar(BuildContext context, WidgetRef ref, String uid) async {
    final bytes = await pickAvatarImage(context);
    if (bytes == null) return;
    try {
      await ref.read(userServiceProvider).updateAvatar(uid, bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update picture: $e')));
      }
    }
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref, String uid) async {
    final me = ref.read(currentUserProvider);
    final nameCtrl = TextEditingController(text: me?.username ?? '');
    final bioCtrl = TextEditingController(text: me?.bio ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit profile',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    hintText: 'Username', prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: (v) =>
                    (v ?? '').trim().length < 4 ? 'At least 4 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: bioCtrl,
                maxLength: 80,
                decoration: const InputDecoration(
                    hintText: 'Status / bio', prefixIcon: Icon(Icons.edit_note_rounded)),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true) {
      await ref
          .read(userServiceProvider)
          .updateProfile(uid, username: nameCtrl.text, bio: bioCtrl.text);
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to read your messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await NotificationService.instance.stop();
    await ref.read(authServiceProvider).logout();
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.spec.primary;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: c, size: 20),
    );
  }
}

/// A tiny live mock-up of the chat UI rendered with the given palette.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.spec,
    required this.brightness,
    required this.selected,
    required this.onTap,
  });

  final PaletteSpec spec;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.build(spec, brightness);
    final p = t.extension<AppPalette>()!;

    Widget bubble(bool mine, double width) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: width,
            height: 12,
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: mine ? p.bubbleMine : p.bubbleOther,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 116,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? spec.primary : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: spec.primary.withValues(alpha: 0.35), blurRadius: 16)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: t.scaffoldBackgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [p.header, spec.primary]),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 8, backgroundColor: spec.secondary),
                      const SizedBox(width: 6),
                      Container(
                        width: 40,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        bubble(false, 60),
                        bubble(true, 50),
                        bubble(false, 40),
                        bubble(true, 66),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: t.colorScheme.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (selected)
                        Icon(Icons.check_circle_rounded, size: 14, color: spec.primary),
                      if (selected) const SizedBox(width: 4),
                      Text(
                        spec.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: t.colorScheme.onSurface,
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
    );
  }
}
