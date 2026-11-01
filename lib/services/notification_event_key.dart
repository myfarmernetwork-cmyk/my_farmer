/// Stabilni ključevi događaja za push obavijesti — sprječavaju ponovni prikaz u trayu.
class NotificationEventKey {
  NotificationEventKey._();

  static String? fromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null || type.isEmpty) return null;

    switch (type) {
      case 'new_order':
        final orderId = _s(data['orderId']);
        return orderId.isEmpty ? type : '$type|$orderId';
      case 'order_status':
        final orderId = _s(data['orderId']);
        final status = _s(data['status']);
        if (orderId.isEmpty) return type;
        return status.isEmpty ? '$type|$orderId' : '$type|$orderId|$status';
      case 'weather_alert':
        final alertKey = _s(data['alertKey']);
        return alertKey.isEmpty ? type : '$type|$alertKey';
      case 'low_stock':
        final productId = _s(data['productId']);
        return productId.isEmpty ? type : '$type|$productId';
      case 'new_product':
        final productId = _s(data['productId']);
        final farmerId = _s(data['farmerId']);
        if (productId.isEmpty && farmerId.isEmpty) return type;
        if (productId.isEmpty) return '$type||$farmerId';
        if (farmerId.isEmpty) return '$type|$productId';
        return '$type|$productId|$farmerId';
      case 'vet_response':
        final requestId = _s(data['requestId']);
        final animalId = _s(data['animalId']);
        if (requestId.isNotEmpty && animalId.isNotEmpty) {
          return '$type|$requestId|$animalId';
        }
        if (requestId.isNotEmpty) return '$type|$requestId';
        return animalId.isEmpty ? type : '$type|$animalId';
      case 'chat_message':
        final messageId = _s(data['messageId']);
        final roomId = _s(data['roomId']);
        final senderId = _s(data['senderId']);
        if (messageId.isNotEmpty && roomId.isNotEmpty) {
          return '$type|$roomId|$messageId';
        }
        if (roomId.isNotEmpty) return '$type|$roomId|$senderId';
        return senderId.isEmpty ? type : '$type|$senderId';
      case 'vet_intake':
        final requestId = _s(data['requestId']);
        return requestId.isEmpty ? type : '$type|$requestId';
      case 'forum_new_topic':
        final topicId = _s(data['topicId']);
        return topicId.isEmpty ? type : '$type|$topicId';
      case 'forum_reply':
        final topicId = _s(data['topicId']);
        final commentId = _s(data['commentId']);
        if (commentId.isNotEmpty) return '$type|$topicId|$commentId';
        return topicId.isEmpty ? type : '$type|$topicId';
      default:
        return type;
    }
  }

  static String? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    return payload;
  }

  static int notificationIdFor(String eventKey) {
    return eventKey.hashCode & 0x7fffffff;
  }

  static String _s(Object? value) => value?.toString().trim() ?? '';
}
