import 'package:cloud_firestore/cloud_firestore.dart';

/// A registered user, stored in `users/{uid}`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.email,
    this.online = false,
    this.lastSeen,
    this.createdAt,
    this.pinnedChats = const [],
    this.favouriteChats = const [],
    this.bio = '',
  });

  final String uid;
  final String username;
  final String email;
  final bool online;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final List<String> pinnedChats;
  final List<String> favouriteChats;
  final String bio;

  String get initials {
    final parts = username.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      username: (data['username'] as String?) ?? 'Unknown',
      email: (data['email'] as String?) ?? '',
      online: (data['online'] as bool?) ?? false,
      lastSeen: _toDate(data['lastSeen']),
      createdAt: _toDate(data['createdAt']),
      pinnedChats: List<String>.from(data['pinnedChats'] ?? const []),
      favouriteChats: List<String>.from(data['favouriteChats'] ?? const []),
      bio: (data['bio'] as String?) ?? '',
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'username': username,
        'usernameLower': username.toLowerCase(),
        'email': email,
        'online': online,
        'bio': bio,
        'pinnedChats': pinnedChats,
        'favouriteChats': favouriteChats,
      };
}

DateTime? _toDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}
