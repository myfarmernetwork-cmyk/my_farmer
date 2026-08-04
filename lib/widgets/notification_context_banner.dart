import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_navigation_provider.dart';
import '../features/seller/farmer_orders_screen.dart';
import '../services/notification_service.dart';

/// Prikazuje za što je bila obavijest dok korisnik ne zatvori banner.
class NotificationContextBanner extends ConsumerWidget {
  const NotificationContextBanner({super.key, this.onOpenOrders});

  /// Kad je korisnik već na ekranu narudžbi — skrolaj/highlight umjesto novog push-a.
  final VoidCallback? onOpenOrders;

  String _messageForIntent(NotificationNavigationIntent intent) {
    if (intent.body != null && intent.body!.trim().isNotEmpty) {
      return intent.body!.trim();
    }

    switch (intent.target) {
      case NotificationTarget.weather:
        final key = intent.weatherAlertKey;
        if (key != null && key.isNotEmpty) {
          return key.tr(
            namedArgs: const {'temp': '—', 'wind': '—', 'rain': '—'},
          );
        }
        return 'weather_alert_title'.tr();
      case NotificationTarget.lowStock:
        final name = intent.productName?.trim();
        if (name != null && name.isNotEmpty) {
          return 'notification_low_stock_body'.tr(namedArgs: {'product': name});
        }
        return 'notification_low_stock_generic'.tr();
      case NotificationTarget.orders:
        return 'notification_new_order_body'.tr();
      case NotificationTarget.buyerOrders:
        return _buyerOrderStatusBody(intent.orderStatus);
      case NotificationTarget.newProduct:
        if (intent.productName != null && intent.productName!.trim().isNotEmpty) {
          return intent.productName!.trim();
        }
        return 'notification_new_product_body'.tr(
          namedArgs: {'product': '—', 'farmer': intent.farmerName ?? '—'},
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
        return 'Novi digitalni karton ljubimca';
      case NotificationTarget.vetResponse:
        final animal = intent.animalName?.trim();
        if (animal != null && animal.isNotEmpty) {
          return 'Veterinar je odgovorio za $animal';
        }
        return 'Veterinar je odgovorio na vaš upit';
      case NotificationTarget.chatMessage:
        return intent.senderName?.trim().isNotEmpty == true
            ? intent.senderName!.trim()
            : 'Nova poruka';
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

  String _buyerOrderStatusBody(String? status) {
    switch (status) {
      case 'preparing':
        return 'notification_order_preparing_body_short'.tr();
      case 'completed':
        return 'notification_order_ready_body_short'.tr();
      default:
        return 'notification_order_status_generic'.tr();
    }
  }

  String _titleForIntent(NotificationNavigationIntent intent) {
    if (intent.title != null && intent.title!.trim().isNotEmpty) {
      return intent.title!.trim();
    }

    switch (intent.target) {
      case NotificationTarget.weather:
        return 'weather_alert_title'.tr();
      case NotificationTarget.lowStock:
        return 'notification_low_stock_title'.tr();
      case NotificationTarget.orders:
        return 'notification_new_order_title'.tr();
      case NotificationTarget.buyerOrders:
        return _buyerOrderStatusTitle(intent.orderStatus);
      case NotificationTarget.newProduct:
        return 'notification_new_product_title'.tr(
          namedArgs: {'farmer': intent.farmerName ?? 'Farmer'},
        );
      case NotificationTarget.vetIntake:
        return 'Novi digitalni karton';
      case NotificationTarget.vetResponse:
        return 'Odgovor veterinara';
      case NotificationTarget.chatMessage:
        return 'Nova poruka';
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

  String _buyerOrderStatusTitle(String? status) {
    switch (status) {
      case 'preparing':
        return 'notification_order_preparing_title'.tr();
      case 'completed':
        return 'notification_order_ready_pickup_title'.tr();
      default:
        return 'notification_order_status_generic_title'.tr();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = ref.watch(notificationIntentProvider);
    if (intent == null) return const SizedBox.shrink();

    final title = _titleForIntent(intent);
    final message = _messageForIntent(intent);
    final service = NotificationService();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_active, color: Colors.orange.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                    if (intent.target == NotificationTarget.newProduct &&
                        intent.productId != null &&
                        intent.productId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          service.openProductFromNotification(intent.productId!);
                        },
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text('notification_open_product'.tr()),
                      ),
                    ],
                    if (intent.target == NotificationTarget.orders &&
                        intent.pushOrdersScreen) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          if (onOpenOrders != null) {
                            onOpenOrders!();
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FarmerOrdersScreen(
                                highlightOrderId: intent.orderId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text('notification_open_orders'.tr()),
                      ),
                    ],
                    if (intent.target == NotificationTarget.vetIntake &&
                        intent.requestId != null &&
                        intent.requestId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          service.openVetRequestFromNotification(
                            intent.requestId!,
                          );
                        },
                        icon: const Icon(Icons.medical_services_outlined, size: 18),
                        label: const Text('Otvori karton'),
                      ),
                    ],
                    if (intent.target == NotificationTarget.vetResponse &&
                        intent.animalId != null &&
                        intent.animalId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          service.openAnimalDetailFromNotification(
                            intent.animalId!,
                          );
                        },
                        icon: const Icon(Icons.pets, size: 18),
                        label: const Text('Otvori profil ljubimca'),
                      ),
                    ],
                    if (intent.target == NotificationTarget.chatMessage &&
                        intent.senderId != null &&
                        intent.senderId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          service.openChatFromNotification(
                            intent.senderId!,
                            intent.senderName ?? 'Korisnik',
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Otvori poruke'),
                      ),
                    ],
                    if ((intent.target == NotificationTarget.forumTopic ||
                            intent.target == NotificationTarget.forumReply) &&
                        intent.topicId != null &&
                        intent.topicId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          service.openForumTopicFromNotification(
                            intent.topicId!,
                          );
                        },
                        icon: const Icon(Icons.forum_outlined, size: 18),
                        label: Text('notification_open_forum_topic'.tr()),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'notification_dismiss'.tr(),
                onPressed: () =>
                    ref.read(notificationIntentProvider.notifier).clear(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
