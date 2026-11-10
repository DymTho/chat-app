import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat.dart';
import '../models/message.dart';

/// Conversations and messages in Cloud Firestore.
class ChatService {
  ChatService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  /// All chats the user is a member of, newest activity first. Sorted on the
  /// client so no composite index is needed.
  Stream<List<Chat>> chatsFor(String uid) => _chats
          .where('members', arrayContains: uid)
          .snapshots()
          .map((snap) {
        final chats = snap.docs.map(Chat.fromDoc).toList();
        chats.sort((a, b) {
          final ta = a.updatedAt ?? DateTime(2000);
          final tb = b.updatedAt ?? DateTime(2000);
          return tb.compareTo(ta);
        });
        return chats;
      });

  Stream<Chat?> chatStream(String chatId) =>
      _chats.doc(chatId).snapshots().map((d) => d.exists ? Chat.fromDoc(d) : null);

  /// Newest first (used by a reversed ListView).
  Stream<List<Message>> messagesStream(String chatId, {int limit = 300}) =>
      _messages(chatId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots(includeMetadataChanges: true)
          .map((snap) => snap.docs.map(Message.fromDoc).toList());

  /// Creates (or re-opens) the 1-to-1 chat between [me] and [other].
  /// The write is not awaited: the local cache has it immediately, so the
  /// chat opens instantly even on a slow connection.
  Future<String> openDirectChat(String me, String other) async {
    final id = Chat.directId(me, other);
    _chats.doc(id).set({
      'type': 'direct',
      'members': [me, other]..sort(),
    }, SetOptions(merge: true)).ignore();
    return id;
  }

  /// Makes sure the user is part of the shared group chat (e.g. accounts made
  /// before the group existed).
  Future<void> ensureGlobalMembership(String uid) => _chats.doc(Chat.globalId).set({
        'type': 'group',
        'name': 'Everyone',
        'members': FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));

  Future<void> sendMessage({
    required Chat chat,
    required String senderId,
    required String senderName,
    required String text,
    ReplyRef? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final batch = _db.batch();
    batch.set(_messages(chat.id).doc(), {
      'text': trimmed,
      'senderId': senderId,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
      'reactions': <String, String>{},
      'deleted': false,
      'edited': false,
      if (replyTo != null) 'replyTo': replyTo.toMap(),
    });
    batch.update(_chats.doc(chat.id), {
      'lastMessage': trimmed,
      'lastSenderId': senderId,
      'lastSenderName': senderName,
      'updatedAt': FieldValue.serverTimestamp(),
      'typing.$senderId': false,
      for (final m in chat.members)
        if (m != senderId) 'unread.$m': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> editMessage(String chatId, String messageId, String text) =>
      _messages(chatId).doc(messageId).update({'text': text.trim(), 'edited': true});

  Future<void> deleteMessage(String chatId, String messageId) =>
      _messages(chatId).doc(messageId).update({
        'text': '',
        'deleted': true,
        'reactions': <String, String>{},
      });

  /// Sets the reaction of [uid]; passing the same emoji again removes it.
  Future<void> toggleReaction({
    required String chatId,
    required Message message,
    required String uid,
    required String emoji,
  }) {
    final current = message.reactions[uid];
    return _messages(chatId).doc(message.id).update({
      'reactions.$uid': current == emoji ? FieldValue.delete() : emoji,
    });
  }

  Future<void> markRead(String chatId, String uid) async {
    try {
      await _chats.doc(chatId).update({'unread.$uid': 0});
    } catch (_) {}
  }

  Future<void> setTyping(String chatId, String uid, bool typing) async {
    try {
      await _chats.doc(chatId).update({'typing.$uid': typing});
    } catch (_) {}
  }
}
