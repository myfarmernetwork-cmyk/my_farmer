import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationTarget {
  orders,
  buyerOrders,
  newProduct,
  weather,
  lowStock,
  vetIntake,
  vetResponse,
  chatMessage,
  forumTopic,
  forumReply,
}

class NotificationNavigationIntent {
  const NotificationNavigationIntent({
    required this.target,
    this.orderId,
    this.orderStatus,
    this.weatherAlertKey,
    this.productId,
    this.farmerId,
    this.farmerName,
    this.productName,
    this.requestId,
    this.animalId,
    this.animalName,
    this.clientName,
    this.senderId,
    this.senderName,
    this.topicId,
    this.topicTitle,
    this.authorName,
    this.title,
    this.body,
    this.pushOrdersScreen = false,
    this.stockCount,
  });

  final NotificationTarget target;
  final String? orderId;
  final String? orderStatus;
  final String? weatherAlertKey;
  final String? productId;
  final String? farmerId;
  final String? farmerName;
  final String? productName;
  final String? requestId;
  final String? animalId;
  final String? animalName;
  final String? clientName;
  final String? senderId;
  final String? senderName;
  final String? topicId;
  final String? topicTitle;
  final String? authorName;
  final String? title;
  final String? body;
  final bool pushOrdersScreen;
  final double? stockCount;
}

class NotificationIntentNotifier
    extends StateNotifier<NotificationNavigationIntent?> {
  NotificationIntentNotifier() : super(null);

  void dispatch(NotificationNavigationIntent intent) {
    state = intent;
  }

  void clear() => state = null;
}

final notificationIntentProvider =
    StateNotifierProvider<NotificationIntentNotifier,
        NotificationNavigationIntent?>((ref) {
  return NotificationIntentNotifier();
});

/// Most iz NotificationService (singleton) prema Riverpod-u.
class NotificationNavigationBridge {
  NotificationNavigationBridge._();

  static NotificationIntentNotifier? _notifier;
  static void Function(NotificationNavigationIntent)? _tabSwitcher;

  static void register(NotificationIntentNotifier notifier) {
    _notifier = notifier;
  }

  static void registerTabSwitcher(
    void Function(NotificationNavigationIntent intent) switcher,
  ) {
    _tabSwitcher = switcher;
  }

  static void unregister() {
    _notifier = null;
    _tabSwitcher = null;
  }

  static void dispatch(NotificationNavigationIntent intent) {
    _notifier?.dispatch(intent);
    _inboxSync?.call(intent);
  }

  static Future<void> Function(NotificationNavigationIntent intent)? _inboxSync;

  static void registerInboxSync(
    Future<void> Function(NotificationNavigationIntent intent) sync,
  ) {
    _inboxSync = sync;
  }

  static void switchToTabFor(NotificationNavigationIntent intent) {
    _tabSwitcher?.call(intent);
  }
}
