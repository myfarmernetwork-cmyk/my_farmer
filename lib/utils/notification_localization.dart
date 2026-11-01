import 'package:easy_localization/easy_localization.dart';

import '../models/in_app_notification.dart';
import '../providers/notification_navigation_provider.dart';

/// Lokalizirani naslovi i tekstovi obavijesti u UI-u (banner, inbox).
class NotificationLocalization {
  static String titleForIntent(NotificationNavigationIntent intent) {
    return _title(intent.target, intent);
  }

  static String bodyForIntent(NotificationNavigationIntent intent) {
    return _body(intent.target, intent);
  }

  static String titleForInApp(InAppNotification notification) {
    final target = notification.navigationTarget;
    if (target == null) {
      return notification.title.trim().isNotEmpty
          ? notification.title
          : 'inbox_notifications_title'.tr();
    }
    return _title(target, notification.toNavigationIntent());
  }

  static String bodyForInApp(InAppNotification notification) {
    final target = notification.navigationTarget;
    if (target == null) {
      return notification.body;
    }
    return _body(target, notification.toNavigationIntent());
  }

  static String _title(
    NotificationTarget target,
    NotificationNavigationIntent intent,
  ) {
    switch (target) {
      case NotificationTarget.weather:
        return 'weather_alert_title'.tr();
      case NotificationTarget.lowStock:
        return 'notification_low_stock_title'.tr();
      case NotificationTarget.orders:
        return _storedOr(
          intent.title,
          'notification_new_order_title'.tr(),
        );
      case NotificationTarget.buyerOrders:
        return _storedOr(
          intent.title,
          _buyerOrderStatusTitle(intent.orderStatus),
        );
      case NotificationTarget.newProduct:
        return 'notification_new_product_title'.tr(
          namedArgs: {'farmer': intent.farmerName ?? 'Farmer'},
        );
      case NotificationTarget.vetIntake:
        return 'notification_vet_intake_title'.tr();
      case NotificationTarget.vetResponse:
        return 'notification_vet_response_title'.tr();
      case NotificationTarget.chatMessage:
        return 'notification_chat_title'.tr();
      case NotificationTarget.forumTopic:
        return intent.topicTitle?.trim().isNotEmpty == true
            ? intent.topicTitle!.trim()
            : 'notification_forum_new_topic_title'.tr();
      case NotificationTarget.forumReply:
        return intent.topicTitle?.trim().isNotEmpty == true
            ? intent.topicTitle!.trim()
            : 'notification_forum_reply_title'.tr();
    }
  }

  static String _body(
    NotificationTarget target,
    NotificationNavigationIntent intent,
  ) {
    switch (target) {
      case NotificationTarget.weather:
        final key = intent.weatherAlertKey;
        if (key != null && key.isNotEmpty) {
          return key.tr(
            namedArgs: const {'temp': '—', 'wind': '—', 'rain': '—'},
          );
        }
        return _storedOr(intent.body, 'weather_alert_title'.tr());
      case NotificationTarget.lowStock:
        return _lowStockBody(intent);
      case NotificationTarget.orders:
        return _storedOr(
          intent.body,
          'notification_new_order_body'.tr(),
        );
      case NotificationTarget.buyerOrders:
        return _storedOr(
          intent.body,
          _buyerOrderStatusBody(intent.orderStatus),
        );
      case NotificationTarget.newProduct:
        if (intent.productName != null &&
            intent.productName!.trim().isNotEmpty) {
          return intent.productName!.trim();
        }
        return 'notification_new_product_body'.tr(
          namedArgs: {
            'product': '—',
            'farmer': intent.farmerName ?? '—',
          },
        );
      case NotificationTarget.vetIntake:
        final animal = intent.animalName?.trim();
        final client = intent.clientName?.trim();
        if (animal != null &&
            animal.isNotEmpty &&
            client != null &&
            client.isNotEmpty) {
          return '$client — $animal';
        }
        if (animal != null && animal.isNotEmpty) return animal;
        return 'notification_vet_intake_body'.tr();
      case NotificationTarget.vetResponse:
        final animal = intent.animalName?.trim();
        if (animal != null && animal.isNotEmpty) {
          return 'notification_vet_response_body'.tr(
            namedArgs: {'animal': animal},
          );
        }
        return 'notification_vet_response_body_generic'.tr();
      case NotificationTarget.chatMessage:
        return intent.senderName?.trim().isNotEmpty == true
            ? intent.senderName!.trim()
            : 'notification_chat_body'.tr();
      case NotificationTarget.forumTopic:
        final author = intent.authorName?.trim();
        if (author != null && author.isNotEmpty) {
          return 'notification_forum_new_topic_body'.tr(
            namedArgs: {'author': author},
          );
        }
        return 'notification_forum_new_topic_body_generic'.tr();
      case NotificationTarget.forumReply:
        if (intent.body != null && intent.body!.trim().isNotEmpty) {
          return intent.body!.trim();
        }
        final author = intent.authorName?.trim();
        if (author != null && author.isNotEmpty) {
          return 'notification_forum_reply_body'.tr(
            namedArgs: {'author': author},
          );
        }
        return 'notification_forum_reply_body_generic'.tr();
    }
  }

  static String _lowStockBody(NotificationNavigationIntent intent) {
    final name = intent.productName?.trim();
    final count = intent.stockCount;
    if (name != null && name.isNotEmpty && count != null) {
      return 'notification_low_stock_body_remaining'.tr(
        namedArgs: {
          'product': name,
          'count': count % 1 == 0
              ? count.toInt().toString()
              : count.toStringAsFixed(1),
        },
      );
    }
    if (name != null && name.isNotEmpty) {
      return 'notification_low_stock_body'.tr(namedArgs: {'product': name});
    }
    return 'notification_low_stock_generic'.tr();
  }

  static String _storedOr(String? stored, String fallback) {
    final value = stored?.trim();
    if (value != null && value.isNotEmpty) return value;
    return fallback;
  }

  static String _buyerOrderStatusBody(String? status) {
    switch (status) {
      case 'preparing':
        return 'notification_order_preparing_body_short'.tr();
      case 'completed':
        return 'notification_order_ready_body_short'.tr();
      case 'rejected':
        return 'notification_order_rejected_body_short'.tr();
      default:
        return 'notification_order_status_generic'.tr();
    }
  }

  static String _buyerOrderStatusTitle(String? status) {
    switch (status) {
      case 'preparing':
        return 'notification_order_preparing_title'.tr();
      case 'completed':
        return 'notification_order_ready_pickup_title'.tr();
      case 'rejected':
        return 'notification_order_rejected_title'.tr();
      default:
        return 'notification_order_status_generic_title'.tr();
    }
  }
}
