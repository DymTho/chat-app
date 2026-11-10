import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../models/chat.dart';
import 'user_service.dart';

/// Set to true after deploying `functions/index.js` (requires the Blaze plan).
/// The server then delivers every push via FCM and the in-app fallback below
/// is switched off to avoid duplicate notifications.
const bool kServerPushEnabled = false;

/// Runs in its own isolate when an FCM message arrives while the app is in
/// the background or terminated. Notification messages are displayed by the
/// OS automatically; this is only needed for data handling.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background FCM message: ${message.messageId}');
}

/// Push notifications.
///
/// 1. Firebase Cloud Messaging: permission, token stored in `users/{uid}`,
///    foreground + background + tap handling (try "Send test message" in the
///    Firebase console).
/// 2. Free-plan fallback: while the app is in the background, a Firestore
///    listener on the user's chats raises a local notification for every new
///    incoming message.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _channel = AndroidNotificationChannel(
    'chat_messages',
    'Chat messages',
    description: 'Notifications for new chat messages',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  final _messaging = FirebaseMessaging.instance;

  /// Chat currently open on screen (no notifications for it while visible).
  String? activeChatId;

  /// Opens a chat when a notification is tapped. Set by the home screen.
  void Function(String chatId)? onOpenChat;

  bool _initialised = false;
  bool _inForeground = true;
  String? _uid;
  String? _pendingChatToOpen;
  StreamSubscription<List<Chat>>? _chatSub;
  final _subs = <StreamSubscription<dynamic>>[];
  AppLifecycleListener? _lifecycle;
  final Map<String, DateTime> _seen = {};
  final Map<String, Uint8List?> _avatarCache = {};

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (r) => _open(r.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _pendingChatToOpen = launch!.notificationResponse?.payload;
    }

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  }

  /// Called after login. Wires FCM and starts watching the user's chats.
  Future<void> start({
    required String uid,
    required Stream<List<Chat>> chats,
    required UserService userService,
    required Map<String, AppUser> Function() users,
    required bool Function() enabled,
  }) async {
    if (_uid == uid) return;
    await stop();
    _uid = uid;

    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final fg = state == AppLifecycleState.resumed;
        if (fg == _inForeground) return;
        _inForeground = fg;
        userService.setPresence(uid, online: fg);
      },
    );
    userService.setPresence(uid, online: true);

    // --- Firebase Cloud Messaging ------------------------------------------
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _messaging.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);

      // getToken() still returns the classic registration token that the
      // console "Send test message" and the Admin SDK expect.
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token != null) await userService.saveFcmToken(uid, token);
      // ignore: deprecated_member_use
      _subs.add(_messaging.onTokenRefresh.listen((t) => userService.saveFcmToken(uid, t)));
      await _messaging.subscribeToTopic('chat').catchError((_) {});

      _subs.add(FirebaseMessaging.onMessage.listen((m) {
        // Android does not show notification messages while in the
        // foreground, so mirror them as a local notification.
        final n = m.notification;
        final chatId = m.data['chatId'] as String?;
        if (n == null || chatId == activeChatId) return;
        if (m.data['senderId'] == uid) return;
        _show(
          id: (chatId ?? m.messageId ?? '').hashCode,
          title: n.title ?? 'New message',
          body: n.body ?? '',
          payload: chatId,
        );
      }));
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data['chatId'] as String?)));
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _pendingChatToOpen ??= initial.data['chatId'] as String?;
    } catch (e) {
      debugPrint('FCM setup failed: $e');
    }

    // --- Free-plan fallback: local notifications from Firestore ------------
    _seen.clear();
    var first = true;
    _chatSub = chats.listen((list) {
      for (final chat in list) {
        final at = chat.updatedAt;
        if (at == null) continue;
        final prev = _seen[chat.id];
        _seen[chat.id] = at;
        if (first || prev == null || !at.isAfter(prev)) continue;
        if (chat.lastSenderId == null || chat.lastSenderId == uid) continue;
        if (chat.unreadFor(uid) == 0) continue;
        if (_inForeground && activeChatId == chat.id) continue;
        if (kServerPushEnabled || !enabled()) continue;
        _notifyForChat(chat, users(), userService);
      }
      first = false;
    });

    final pending = _pendingChatToOpen;
    _pendingChatToOpen = null;
    if (pending != null) _open(pending);
  }

  Future<void> stop() async {
    await _chatSub?.cancel();
    _chatSub = null;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _lifecycle?.dispose();
    _lifecycle = null;
    _uid = null;
    _seen.clear();
    try {
      await _messaging.unsubscribeFromTopic('chat');
      await _local.cancelAll();
    } catch (_) {}
  }

  Future<void> clearChat(String chatId) async {
    try {
      await _local.cancel(id: chatId.hashCode);
    } catch (_) {}
  }

  Future<void> _notifyForChat(
    Chat chat,
    Map<String, AppUser> users,
    UserService userService,
  ) async {
    final senderId = chat.lastSenderId!;
    final sender = users[senderId]?.username ?? 'New message';
    final title = chat.isGroup ? '${chat.name ?? 'Group'} · $sender' : sender;
    final unread = chat.unreadFor(_uid ?? '');

    Uint8List? avatar = _avatarCache[senderId];
    if (!_avatarCache.containsKey(senderId)) {
      try {
        avatar = await userService
            .avatarStream(senderId)
            .first
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        avatar = null;
      }
      _avatarCache[senderId] = avatar;
    }

    await _show(
      id: chat.id.hashCode,
      title: title,
      body: chat.lastMessage,
      payload: chat.id,
      largeIcon: avatar,
      subText: unread > 1 ? '$unread new messages' : null,
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
    Uint8List? largeIcon,
    String? subText,
  }) async {
    final android = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      largeIcon: largeIcon == null
          ? null
          : ByteArrayAndroidBitmap.fromBase64String(base64Encode(largeIcon)),
      subText: subText,
      styleInformation: BigTextStyleInformation(body),
      color: const Color(0xFFF2784B),
    );
    try {
      await _local.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: android,
          iOS: const DarwinNotificationDetails(threadIdentifier: 'chat'),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }

  void _open(String? chatId) {
    if (chatId == null || chatId.isEmpty) return;
    final handler = onOpenChat;
    if (handler == null) {
      _pendingChatToOpen = chatId;
    } else {
      handler(chatId);
    }
  }
}
