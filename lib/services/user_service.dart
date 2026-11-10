import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Profiles, avatars, presence and per-user chat preferences.
class UserService {
  UserService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Stream<Map<String, AppUser>> usersStream() => _users.snapshots().map(
        (snap) => {for (final d in snap.docs) d.id: AppUser.fromDoc(d)},
      );

  Stream<AppUser?> userStream(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  /// Profile pictures live in `avatars/{uid}` as base64 JPEG (Spark plan has
  /// no Cloud Storage), separate from the user doc so lists stay light.
  Stream<Uint8List?> avatarStream(String uid) =>
      _db.collection('avatars').doc(uid).snapshots().map((d) {
        final data = d.data()?['data'];
        if (data is! String || data.isEmpty) return null;
        try {
          return base64Decode(data);
        } catch (_) {
          return null;
        }
      });

  Future<void> updateAvatar(String uid, Uint8List bytes) =>
      _db.collection('avatars').doc(uid).set({
        'data': base64Encode(bytes),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateProfile(String uid, {String? username, String? bio}) {
    return _users.doc(uid).update({
      if (username != null) 'username': username.trim(),
      if (username != null) 'usernameLower': username.trim().toLowerCase(),
      if (bio != null) 'bio': bio.trim(),
    });
  }

  Future<void> setPresence(String uid, {required bool online}) async {
    try {
      await _users.doc(uid).update({
        'online': online,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Presence is best effort.
    }
  }

  Future<void> saveFcmToken(String uid, String token) =>
      _users.doc(uid).set({'fcmToken': token}, SetOptions(merge: true));

  Future<void> setPinned(String uid, String chatId, bool pinned) =>
      _users.doc(uid).update({
        'pinnedChats': pinned
            ? FieldValue.arrayUnion([chatId])
            : FieldValue.arrayRemove([chatId]),
      });

  Future<void> setFavourite(String uid, String chatId, bool favourite) =>
      _users.doc(uid).update({
        'favouriteChats': favourite
            ? FieldValue.arrayUnion([chatId])
            : FieldValue.arrayRemove([chatId]),
      });
}
