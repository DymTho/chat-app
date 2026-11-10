import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_palette.dart';

/// Round profile picture loaded from Firestore, with an optional online dot
/// and an optional "story" gradient ring.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.uid,
    this.size = 48,
    this.showOnline = false,
    this.ring = false,
    this.heroTag,
  });

  final String uid;
  final double size;
  final bool showOnline;
  final bool ring;
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(avatarProvider(uid)).value;
    final user = ref.watch(usersProvider.select((u) => u.value?[uid]));
    final palette = context.palette;

    Widget avatar = _AvatarCircle(
      bytes: bytes,
      initials: user?.initials ?? '?',
      size: size,
    );

    if (heroTag != null) {
      avatar = Hero(tag: heroTag!, child: avatar);
    }

    if (ring) {
      avatar = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [
            palette.spec.primary,
            palette.spec.secondary,
            palette.spec.primary,
          ]),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: avatar,
        ),
      );
    }

    if (!showOnline) return avatar;
    final dot = (size * 0.27).clamp(10.0, 18.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: ring ? 2 : 0,
          bottom: ring ? 2 : 0,
          child: AnimatedScale(
            scale: user?.online == true ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: palette.online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.bytes, required this.initials, required this.size});

  final Uint8List? bytes;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: bytes != null
          ? ClipOval(
              key: ValueKey(bytes.hashCode),
              child: Image.memory(
                bytes!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              ),
            )
          : Container(
              key: const ValueKey('initials'),
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: palette.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: size * 0.36,
                ),
              ),
            ),
    );
  }
}

/// Avatar for a group chat: stacked members or a gradient icon.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, this.size = 48, this.heroTag});

  final double size;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [palette.spec.primary, palette.spec.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.groups_rounded, color: Colors.white, size: size * 0.52),
    );
    return heroTag == null ? child : Hero(tag: heroTag!, child: child);
  }
}
