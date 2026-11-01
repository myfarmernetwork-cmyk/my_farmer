import 'package:firebase_auth/firebase_auth.dart';

import '../models/in_app_notification.dart';
import '../providers/notification_navigation_provider.dart';
import '../utils/notification_localization.dart';
import '../repositories/in_app_notification_repository.dart';

class InAppInboxSync {
  InAppInboxSync(this._repository);

  final InAppNotificationRepository _repository;

  static String _typeForTarget(NotificationTarget target) {
    switch (target) {
      case NotificationTarget.orders:
        return 'new_order';
      case NotificationTarget.buyerOrders:
        return 'order_status';
      case NotificationTarget.newProduct:
        return 'new_product';
      case NotificationTarget.weather:
        return 'weather_alert';
      case NotificationTarget.lowStock:
        return 'low_stock';
      case NotificationTarget.vetIntake:
        return 'vet_intake';
      case NotificationTarget.vetResponse:
        return 'vet_response';
      case NotificationTarget.chatMessage:
        return 'chat_message';
      case NotificationTarget.forumTopic:
        return 'forum_new_topic';
      case NotificationTarget.forumReply:
        return 'forum_reply';
    }
  }

  Future<void> recordIntent(NotificationNavigationIntent intent) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final type = _typeForTarget(intent.target);
    final title = (intent.title ?? '').trim();
    final body = (intent.body ?? '').trim();
    final storedTitle = title.isNotEmpty
        ? title
        : NotificationLocalization.titleForIntent(intent);
    final storedBody = body.isNotEmpty
        ? body
        : NotificationLocalization.bodyForIntent(intent);
    if (storedTitle.isEmpty && storedBody.isEmpty) return;

    final data = <String, dynamic>{
      'type': type,
      if (intent.orderId != null) 'orderId': intent.orderId,
      if (intent.orderStatus != null) 'orderStatus': intent.orderStatus,
      if (intent.productId != null) 'productId': intent.productId,
      if (intent.farmerId != null) 'farmerId': intent.farmerId,
      if (intent.productName != null) 'productName': intent.productName,
      if (intent.stockCount != null) 'stockCount': intent.stockCount,
      if (intent.requestId != null) 'requestId': intent.requestId,
      if (intent.animalId != null) 'animalId': intent.animalId,
      if (intent.senderId != null) 'senderId': intent.senderId,
      if (intent.topicId != null) 'topicId': intent.topicId,
      if (intent.weatherAlertKey != null) 'weatherAlertKey': intent.weatherAlertKey,
    };

    final docId = InAppNotificationRepository.docIdFromData(data);
    final notification = InAppNotification(
      id: docId,
      type: type,
      title: storedTitle,
      body: storedBody.isNotEmpty ? storedBody : storedTitle,
      orderId: intent.orderId,
      orderStatus: intent.orderStatus,
      productId: intent.productId,
      farmerId: intent.farmerId,
      farmerName: intent.farmerName,
      productName: intent.productName,
      stockCount: intent.stockCount,
      requestId: intent.requestId,
      animalId: intent.animalId,
      animalName: intent.animalName,
      senderId: intent.senderId,
      senderName: intent.senderName,
      topicId: intent.topicId,
      weatherAlertKey: intent.weatherAlertKey,
    );

    await _repository.upsertNotification(
      userId: uid,
      docId: docId,
      notification: notification,
    );
  }
}
