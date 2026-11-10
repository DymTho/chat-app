import 'package:cloud_firestore/cloud_firestore.dart';

/// A short reference to the message being replied to.
class ReplyRef {
  const ReplyRef({required this.id, required this.text, required this.senderName});

  final String id;
  final String text;
  final String senderName;

  factory ReplyRef.fromMap(Map<String, dynamic> data) => ReplyRef(
        id: (data['id'] as String?) ?? '',
        text: (data['text'] as String?) ?? '',
        senderName: (data['senderName'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'senderName': senderName};
}

/// A chat message, stored in `chats/{chatId}/messages/{id}`.
class Message {
  const Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    this.createdAt,
    this.replyTo,
    this.reactions = const {},
    this.deleted = false,
    this.edited = false,
  });

  final String id;
  final String text;
  final String senderId;
  final String senderName;

  /// Null while the server timestamp is still pending (optimistic local write).
  final DateTime? createdAt;
  final ReplyRef? replyTo;

  /// uid → emoji
  final Map<String, String> reactions;
  final bool deleted;
  final bool edited;

  bool get isPending => createdAt == null;

  /// Emoji → number of users that reacted with it, most popular first.
  List<MapEntry<String, int>> get reactionSummary {
    final counts = <String, int>{};
    for (final e in reactions.values) {
      counts[e] = (counts[e] ?? 0) + 1;
    }
    return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  factory Message.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    final reply = data['replyTo'];
    return Message(
      id: id,
      text: (data['text'] as String?) ?? '',
      senderId: (data['senderId'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
      replyTo: reply is Map<String, dynamic> ? ReplyRef.fromMap(reply) : null,
      reactions: (data['reactions'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, v.toString())),
      deleted: (data['deleted'] as bool?) ?? false,
      edited: (data['edited'] as bool?) ?? false,
    );
  }

  factory Message.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Message.fromMap(doc.id, doc.data() ?? const {});
}
