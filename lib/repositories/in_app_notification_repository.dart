import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/in_app_notification.dart';

class InAppNotificationRepository {
  InAppNotificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _inboxRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('inbox_notifications');

  Stream<List<InAppNotification>> watchNotifications(String userId) {
    return _inboxRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(InAppNotification.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<int> watchUnreadCount(String userId) {
    return _inboxRef(userId)
        .where('readAt', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> upsertNotification({
    required String userId,
    required String docId,
    required InAppNotification notification,
  }) async {
    await _inboxRef(userId).doc(docId).set(
      notification.toWriteMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    await _inboxRef(userId).doc(notificationId).update({
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final snap = await _inboxRef(userId).where('readAt', isNull: true).get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  static String docIdFromData(Map<String, dynamic> data) {
    final type = (data['type'] as String? ?? 'unknown').trim();
    switch (type) {
      case 'new_order':
        return 'new_order_${data['orderId'] ?? 'x'}';
      case 'order_status':
        return 'order_status_${data['orderId'] ?? 'x'}_${data['status'] ?? data['orderStatus'] ?? 'x'}';
      case 'new_product':
        return 'new_product_${data['productId'] ?? data['farmerId'] ?? 'x'}';
      case 'vet_response':
        return 'vet_response_${data['requestId'] ?? data['animalId'] ?? 'x'}';
      case 'vet_intake':
        return 'vet_intake_${data['requestId'] ?? 'x'}';
      case 'chat_message':
        return 'chat_${data['roomId'] ?? data['senderId'] ?? 'x'}_${data['messageId'] ?? DateTime.now().millisecondsSinceEpoch}';
      case 'forum_new_topic':
        return 'forum_topic_${data['topicId'] ?? 'x'}';
      case 'forum_reply':
        return 'forum_reply_${data['topicId'] ?? 'x'}_${data['commentId'] ?? 'x'}';
      case 'weather_alert':
        return 'weather_${data['alertKey'] ?? DateTime.now().millisecondsSinceEpoch}';
      case 'low_stock':
        return 'low_stock_${data['productId'] ?? 'x'}';
      default:
        return '${type}_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}

final inAppNotificationRepositoryProvider =
    Provider<InAppNotificationRepository>(
  (ref) => InAppNotificationRepository(FirebaseFirestore.instance),
);

final inboxNotificationsProvider =
    StreamProvider.autoDispose<List<InAppNotification>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(inAppNotificationRepositoryProvider).watchNotifications(uid);
});

final inboxUnreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return ref.watch(inAppNotificationRepositoryProvider).watchUnreadCount(uid);
});
