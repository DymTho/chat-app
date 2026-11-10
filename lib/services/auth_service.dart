import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat.dart';

/// Wraps Firebase Authentication and the user documents created on sign-up.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> login({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  /// Creates the account, stores the profile + avatar in Firestore and joins
  /// the shared "Everyone" group chat.
  Future<void> signUp({
    required String email,
    required String username,
    required String password,
    required Uint8List avatarBytes,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;
    try {
      await credential.user!.updateDisplayName(username.trim());

      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), {
        'username': username.trim(),
        'usernameLower': username.trim().toLowerCase(),
        'email': email.trim(),
        'bio': '',
        'online': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'pinnedChats': <String>[],
        'favouriteChats': <String>[],
      });
      batch.set(_db.collection('avatars').doc(uid), {
        'data': base64Encode(avatarBytes),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      await _db.collection('chats').doc(Chat.globalId).set({
        'type': 'group',
        'name': 'Everyone',
        'members': FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));
    } catch (_) {
      // Do not leave a half-created account behind.
      await credential.user?.delete();
      rethrow;
    }
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _db.collection('users').doc(uid).update({
          'online': false,
          'lastSeen': FieldValue.serverTimestamp(),
          'fcmToken': FieldValue.delete(),
        });
      } catch (_) {
        // Logging out must succeed even when offline.
      }
    }
    await _auth.signOut();
  }

  /// Human friendly text for Firebase auth error codes.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'INVALID_LOGIN_CREDENTIALS':
          return 'Wrong email or password. Please try again.';
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'weak-password':
          return 'Password is too weak — use at least 6 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a moment and try again.';
        case 'network-request-failed':
          return 'No internet connection.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled in Firebase.';
      }
      return error.message ?? 'Authentication failed.';
    }
    if (error is FirebaseException) {
      return error.message ?? 'Something went wrong (${error.code}).';
    }
    return 'Something went wrong. Please try again.';
  }
}
