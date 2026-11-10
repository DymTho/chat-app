import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType { direct, group }

/// A conversation, stored in `chats/{chatId}`.
class Chat {
  const Chat({
    required this.id,
    required this.type,
    required this.members,
    this.name,
    this.lastMessage = '',
    this.lastSenderId,
    this.updatedAt,
    this.unread = const {},
    this.typing = const {},
  });

  static const globalId = 'global';

  final String id;
  final ChatType type;
  final List<String> members;
  final String? name;
  final String lastMessage;
  final String? lastSenderId;
  final DateTime? updatedAt;
  final Map<String, int> unread;
  final Map<String, bool> typing;

  bool get isGroup => type == ChatType.group;

  int unreadFor(String uid) => unread[uid] ?? 0;

  /// For a direct chat, the uid of the other participant.
  String? otherMember(String me) {
    if (isGroup) return null;
    return members.firstWhere((m) => m != me, orElse: () => me);
  }

  /// Members other than [me] that are currently typing.
  List<String> typingUsers(String me) => typing.entries
      .where((e) => e.value && e.key != me)
      .map((e) => e.key)
      .toList();

  /// Deterministic id for a 1-to-1 chat so both users open the same document.
  static String directId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  factory Chat.fromMap(String id, Map<String, dynamic> data) {
    final updated = data['updatedAt'];
    return Chat(
      id: id,
      type: data['type'] == 'group' ? ChatType.group : ChatType.direct,
      members: List<String>.from(data['members'] ?? const []),
      name: data['name'] as String?,
      lastMessage: (data['lastMessage'] as String?) ?? '',
      lastSenderId: data['lastSenderId'] as String?,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
      unread: (data['unread'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      typing: (data['typing'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, v == true)),
    );
  }

  factory Chat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Chat.fromMap(doc.id, doc.data() ?? const {});
}
