import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../theme/app_palette.dart';
import 'user_avatar.dart';

/// One chat bubble with optional sender header, reply quote and reactions.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.myUid,
    required this.senderName,
    this.onLongPress,
    this.onReactionTap,
    this.onReply,
    this.animate = false,
  });

  final Message message;
  final bool isMine;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final String myUid;
  final String senderName;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onReactionTap;
  final VoidCallback? onReply;
  final bool animate;

  static const _avatarSize = 34.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;
    const r = Radius.circular(20);
    const small = Radius.circular(6);

    final bg = isMine ? palette.bubbleMine : palette.bubbleOther;
    final fg = isMine ? palette.onBubbleMine : palette.onBubbleOther;

    final radius = BorderRadius.only(
      topLeft: !isMine && !isFirstInGroup ? small : r,
      topRight: isMine && !isFirstInGroup ? small : r,
      bottomLeft: !isMine && isLastInGroup ? small : (!isMine ? small : r),
      bottomRight: isMine && isLastInGroup ? small : (isMine ? small : r),
    );

    final time = message.createdAt == null
        ? ''
        : DateFormat.Hm().format(message.createdAt!);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        gradient: isMine && !message.deleted
            ? LinearGradient(
                colors: [
                  Color.lerp(palette.bubbleMine, Colors.white, 0.12)!,
                  palette.bubbleMine,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: isMine
            ? [
                BoxShadow(
                  color: palette.bubbleMine.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.replyTo != null && !message.deleted)
            _ReplyQuote(reply: message.replyTo!, isMine: isMine),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                message.deleted ? 'This message was deleted' : message.text,
                style: TextStyle(
                  color: message.deleted ? fg.withValues(alpha: 0.6) : fg,
                  fontSize: 14.5,
                  height: 1.35,
                  fontStyle: message.deleted ? FontStyle.italic : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.edited && !message.deleted)
                      Text('edited · ',
                          style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.6))),
                    Text(time, style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.7))),
                    if (isMine) ...[
                      const SizedBox(width: 3),
                      Icon(
                        message.isPending ? Icons.schedule_rounded : Icons.done_all_rounded,
                        size: 13,
                        color: fg.withValues(alpha: 0.8),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final reactions = message.reactionSummary;

    Widget content = Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isMine && isFirstInGroup)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: Text(
              senderName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.spec.primary,
              ),
            ),
          ),
        GestureDetector(onLongPress: onLongPress, child: bubble),
        if (reactions.isNotEmpty)
          Transform.translate(
            offset: const Offset(0, -6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final r in reactions)
                    GestureDetector(
                      onTap: () => onReactionTap?.call(r.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: message.reactions[myUid] == r.key
                              ? palette.spec.primary.withValues(alpha: 0.18)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          r.value > 1 ? '${r.key} ${r.value}' : r.key,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ).animate().scale(curve: Curves.easeOutBack, duration: 300.ms),
                ],
              ),
            ),
          ),
      ],
    );

    content = Row(
      mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMine) ...[
          SizedBox(
            width: _avatarSize,
            child: isLastInGroup || isFirstInGroup
                ? Padding(
                    padding: EdgeInsets.only(bottom: reactions.isNotEmpty ? 18 : 0),
                    child: UserAvatar(uid: message.senderId, size: _avatarSize),
                  )
                : null,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(child: content),
      ],
    );

    content = Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: isFirstInGroup ? 10 : 2,
        bottom: reactions.isNotEmpty ? 0 : 2,
      ),
      child: _SwipeToReply(onReply: message.deleted ? null : onReply, child: content),
    );

    if (!animate) return content;
    return content
        .animate()
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic, duration: 300.ms)
        .scaleXY(
          begin: 0.92,
          end: 1,
          alignment: isMine ? Alignment.bottomRight : Alignment.bottomLeft,
          curve: Curves.easeOutBack,
        );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.reply, required this.isMine});

  final ReplyRef reply;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = isMine ? palette.onBubbleMine : palette.onBubbleOther;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: (isMine ? Colors.white : palette.spec.primary).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: isMine ? Colors.white : palette.spec.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(reply.senderName,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isMine ? Colors.white : palette.spec.primary,
              )),
          Text(
            reply.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: fg.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

/// Drag a bubble to the right to reply to it.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.child, required this.onReply});

  final Widget child;
  final VoidCallback? onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _dx = 0;
  bool _triggered = false;
  static const _threshold = 64.0;

  @override
  Widget build(BuildContext context) {
    if (widget.onReply == null) return widget.child;
    final progress = (_dx / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, _threshold * 1.3));
        if (_dx >= _threshold && !_triggered) {
          _triggered = true;
          Feedback.forLongPress(context);
        }
      },
      onHorizontalDragEnd: (_) {
        if (_triggered) widget.onReply?.call();
        setState(() {
          _dx = 0;
          _triggered = false;
        });
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Opacity(
            opacity: progress,
            child: Transform.scale(
              scale: 0.5 + progress * 0.5,
              child: Icon(Icons.reply_rounded, color: context.palette.spec.primary),
            ),
          ),
          AnimatedContainer(
            duration: Duration(milliseconds: _dx == 0 ? 220 : 0),
            curve: Curves.easeOutBack,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Three bouncing dots.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        )
            .animate(onPlay: (ctl) => ctl.repeat())
            .moveY(begin: 0, end: -4, delay: (i * 140).ms, duration: 280.ms, curve: Curves.easeOut)
            .then()
            .moveY(begin: -4, end: 0, duration: 280.ms, curve: Curves.easeIn)
            .then(delay: 400.ms),
      ),
    );
  }
}
