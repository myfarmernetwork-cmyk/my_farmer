import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_navigation_provider.dart';
import '../utils/notification_localization.dart';
import '../services/notification_service.dart';

/// In-app obavijest — kratko objašnjenje; tap vodi direktno na izvor.
class NotificationContextBanner extends ConsumerWidget {
  const NotificationContextBanner({super.key, this.onOpenOrders});

  /// Kad je korisnik već na ekranu narudžbi — samo highlight umjesto novog push-a.
  final VoidCallback? onOpenOrders;

  String _messageForIntent(NotificationNavigationIntent intent) {
    return NotificationLocalization.bodyForIntent(intent);
  }

  String _titleForIntent(NotificationNavigationIntent intent) {
    return NotificationLocalization.titleForIntent(intent);
  }

  String _openLabelForIntent(NotificationNavigationIntent intent) {
    switch (intent.target) {
      case NotificationTarget.weather:
        return 'notification_open_weather'.tr();
      case NotificationTarget.lowStock:
        return 'notification_open_stock_product'.tr();
      case NotificationTarget.orders:
      case NotificationTarget.buyerOrders:
        return 'notification_open_orders'.tr();
      case NotificationTarget.newProduct:
        return 'notification_open_product'.tr();
      case NotificationTarget.vetIntake:
        return 'notification_open_vet_intake'.tr();
      case NotificationTarget.vetResponse:
        return 'notification_open_vet_response'.tr();
      case NotificationTarget.chatMessage:
        return 'notification_open_chat'.tr();
      case NotificationTarget.forumTopic:
      case NotificationTarget.forumReply:
        return 'notification_open_forum_topic'.tr();
    }
  }

  Future<void> _openIntent(
    BuildContext context,
    WidgetRef ref,
    NotificationNavigationIntent intent,
  ) async {
    if (intent.target == NotificationTarget.orders && onOpenOrders != null) {
      onOpenOrders!();
      return;
    }
    if (intent.target == NotificationTarget.buyerOrders && onOpenOrders != null) {
      onOpenOrders!();
      return;
    }

    ref.read(notificationIntentProvider.notifier).clear();
    await NotificationService().navigateFromIntent(intent);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = ref.watch(notificationIntentProvider);
    if (intent == null) return const SizedBox.shrink();

    final title = _titleForIntent(intent);
    final message = _messageForIntent(intent);
    final openLabel = _openLabelForIntent(intent);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openIntent(context, ref, intent),
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
                      const SizedBox(height: 6),
                      Text(
                        openLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                          decoration: TextDecoration.underline,
                        ),
                      ),
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
      ),
    );
  }
}
