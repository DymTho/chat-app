/**
 * OPTIONAL — requires the Firebase Blaze plan.
 *
 * Sends a real FCM push notification to every other member of a chat when a
 * new message is written, so notifications arrive even when the app has been
 * killed. Deploy with:
 *
 *   cd functions && npm install && cd .. && firebase deploy --only functions
 *
 * After deploying, set `kServerPushEnabled = true` in
 * lib/services/notification_service.dart to turn off the in-app fallback.
 */
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.notifyNewMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;
    const { chatId } = event.params;
    const db = getFirestore();

    const chatSnap = await db.doc(`chats/${chatId}`).get();
    const chat = chatSnap.data();
    if (!chat) return;

    const recipients = (chat.members || []).filter((uid) => uid !== message.senderId);
    if (recipients.length === 0) return;

    const userSnaps = await db.getAll(...recipients.map((uid) => db.doc(`users/${uid}`)));
    const tokens = userSnaps.map((s) => s.get("fcmToken")).filter(Boolean);
    if (tokens.length === 0) return;

    const title = chat.type === "group"
      ? `${chat.name || "Group"} · ${message.senderName}`
      : message.senderName;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body: message.text },
      data: { chatId, senderId: message.senderId },
      android: {
        priority: "high",
        notification: { channelId: "chat_messages", tag: chatId },
      },
      apns: { payload: { aps: { sound: "default", threadId: chatId } } },
    });

    console.log(`Sent ${response.successCount}/${tokens.length} notifications for ${chatId}`);
  },
);
