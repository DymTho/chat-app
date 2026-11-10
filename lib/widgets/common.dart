import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../theme/app_palette.dart';

/// Rounded card that turns into frosted glass on the "Sky" palette.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: palette.spec.glass ? null : palette.softShadow,
        border: palette.spec.glass
            ? Border.all(color: Colors.white.withValues(alpha: palette.isDark ? 0.08 : 0.6))
            : null,
      ),
      child: child,
    );
    final content = palette.spec.glass
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: box,
            ),
          )
        : box;
    return margin == null ? content : Padding(padding: margin!, child: content);
  }
}

/// Soft background: plain colour, or a gradient wash for glass palettes.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    if (!palette.spec.glass && palette.spec.id != PaletteId.neon) {
      return ColoredBox(color: bg, child: child);
    }
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: bg)),
        Positioned(
          top: -120,
          right: -80,
          child: _Blob(color: palette.spec.primary, size: 320),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: _Blob(color: palette.spec.secondary, size: 360),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: palette.spec.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: palette.spec.primary),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: 1.06, duration: 1400.ms, curve: Curves.easeInOut),
            const SizedBox(height: 18),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted, fontSize: 13)),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }
}

/// Small rounded counter used for unread messages.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.color});

  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.spec.primary;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: count <= 0
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(count),
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(11)),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }
}

/// "12:30", "Yesterday", "Mon", "12.03.26"
String formatChatTime(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return DateFormat.Hm().format(time);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat.E().format(time);
  return DateFormat('dd.MM.yy').format(time);
}

String formatDayHeader(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat.EEEE().format(time);
  return DateFormat('d MMMM y').format(time);
}

String formatLastSeen(DateTime? time) {
  if (time == null) return 'offline';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'last seen just now';
  if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
  if (diff.inHours < 24) return 'last seen at ${DateFormat.Hm().format(time)}';
  return 'last seen ${formatChatTime(time).toLowerCase()}';
}
