import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/notification_navigation_provider.dart';

class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.createdAt,
    this.readAt,
    this.orderId,
    this.orderStatus,
    this.productId,
    this.farmerId,
    this.farmerName,
    this.productName,
    this.requestId,
    this.animalId,
    this.animalName,
    this.vetName,
    this.senderId,
    this.senderName,
    this.topicId,
    this.weatherAlertKey,
    this.stockCount,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Timestamp? createdAt;
  final Timestamp? readAt;
  final String? orderId;
  final String? orderStatus;
  final String? productId;
  final String? farmerId;
  final String? farmerName;
  final String? productName;
  final String? requestId;
  final String? animalId;
  final String? animalName;
  final String? vetName;
  final String? senderId;
  final String? senderName;
  final String? topicId;
  final String? weatherAlertKey;
  final double? stockCount;

  bool get isRead => readAt != null;

  NotificationTarget? get navigationTarget {
    switch (type) {
      case 'new_order':
        return NotificationTarget.orders;
      case 'order_status':
        return NotificationTarget.buyerOrders;
      case 'new_product':
        return NotificationTarget.newProduct;
      case 'weather_alert':
        return NotificationTarget.weather;
      case 'low_stock':
        return NotificationTarget.lowStock;
      case 'vet_intake':
        return NotificationTarget.vetIntake;
      case 'vet_response':
        return NotificationTarget.vetResponse;
      case 'chat_message':
        return NotificationTarget.chatMessage;
      case 'forum_new_topic':
        return NotificationTarget.forumTopic;
      case 'forum_reply':
        return NotificationTarget.forumReply;
      default:
        return null;
    }
  }

  NotificationNavigationIntent toNavigationIntent() {
    final target = navigationTarget ?? NotificationTarget.weather;
    return NotificationNavigationIntent(
      target: target,
      orderId: orderId,
      orderStatus: orderStatus,
      productId: productId,
      farmerId: farmerId,
      farmerName: farmerName,
      productName: productName,
      requestId: requestId,
      animalId: animalId,
      animalName: animalName,
      senderId: senderId,
      senderName: senderName,
      topicId: topicId,
      weatherAlertKey: weatherAlertKey,
      stockCount: stockCount,
      title: title,
      body: body,
      pushOrdersScreen: target == NotificationTarget.orders,
    );
  }

  factory InAppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return InAppNotification(
      id: doc.id,
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp?,
      readAt: data['readAt'] as Timestamp?,
      orderId: data['orderId'] as String?,
      orderStatus: data['orderStatus'] as String?,
      productId: data['productId'] as String?,
      farmerId: data['farmerId'] as String?,
      farmerName: data['farmerName'] as String?,
      productName: data['productName'] as String?,
      requestId: data['requestId'] as String?,
      animalId: data['animalId'] as String?,
      animalName: data['animalName'] as String?,
      vetName: data['vetName'] as String?,
      senderId: data['senderId'] as String?,
      senderName: data['senderName'] as String?,
      topicId: data['topicId'] as String?,
      weatherAlertKey: data['weatherAlertKey'] as String?,
      stockCount: _parseStockCount(data['stockCount']),
    );
  }

  static double? _parseStockCount(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  Map<String, dynamic> toWriteMap() {
    return {
      'type': type,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      if (orderId != null) 'orderId': orderId,
      if (orderStatus != null) 'orderStatus': orderStatus,
      if (productId != null) 'productId': productId,
      if (farmerId != null) 'farmerId': farmerId,
      if (farmerName != null) 'farmerName': farmerName,
      if (productName != null) 'productName': productName,
      if (requestId != null) 'requestId': requestId,
      if (animalId != null) 'animalId': animalId,
      if (animalName != null) 'animalName': animalName,
      if (vetName != null) 'vetName': vetName,
      if (senderId != null) 'senderId': senderId,
      if (senderName != null) 'senderName': senderName,
      if (topicId != null) 'topicId': topicId,
      if (weatherAlertKey != null) 'weatherAlertKey': weatherAlertKey,
      if (stockCount != null) 'stockCount': stockCount,
    };
  }
}
