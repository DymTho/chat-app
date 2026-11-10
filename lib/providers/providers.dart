import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final userServiceProvider = Provider<UserService>((ref) => UserService());
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// uid of the signed-in user, or null.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

/// Every registered user, keyed by uid.
final usersProvider = StreamProvider<Map<String, AppUser>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(userServiceProvider).usersStream();
});

final currentUserProvider = Provider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return ref.watch(usersProvider).value?[uid];
});

final avatarProvider = StreamProvider.family<Uint8List?, String>((ref, uid) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(null);
  return ref.watch(userServiceProvider).avatarStream(uid);
});

final myChatsProvider = StreamProvider<List<Chat>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(chatServiceProvider).chatsFor(uid);
});

final chatProvider = StreamProvider.autoDispose.family<Chat?, String>(
  (ref, chatId) => ref.watch(chatServiceProvider).chatStream(chatId),
);

final messagesProvider = StreamProvider.autoDispose.family<List<Message>, String>(
  (ref, chatId) => ref.watch(chatServiceProvider).messagesStream(chatId),
);

/// Display title for a chat from the point of view of [me].
String chatTitle(Chat chat, String me, Map<String, AppUser> users) {
  if (chat.isGroup) return chat.name ?? 'Group';
  final other = chat.otherMember(me);
  return users[other]?.username ?? 'Chat';
}
