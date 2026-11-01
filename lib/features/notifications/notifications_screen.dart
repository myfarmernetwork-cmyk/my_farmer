import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/in_app_notification.dart';
import '../../repositories/in_app_notification_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/agro_accent_colors.dart';
import '../../utils/notification_localization.dart';
import '../../utils/chat_time_formatter.dart';
import '../../utils/scroll_bottom_padding.dart';
import '../../widgets/agro_glass_chrome.dart';

class NotificationsBellButton extends ConsumerWidget {
  const NotificationsBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(inboxUnreadCountProvider).valueOrNull ?? 0;

    return AgroHeaderIconButton(
      icon: Icons.notifications_outlined,
      tooltip: 'inbox_notifications_title'.tr(),
      badgeCount: unread,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const _chipGreen = AgroAccentColors.marketplaceChipGreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(inboxNotificationsProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AgroAccentColors.marketplaceUnifiedGreen,
      appBar: AgroGlassAppBar(
        unifiedMarketplaceHeader: true,
        title: Text('inbox_notifications_title'.tr()),
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () => ref
                  .read(inAppNotificationRepositoryProvider)
                  .markAllAsRead(uid),
              child: Text(
                'inbox_mark_all_read'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AgroAccentColors.marketplaceUnifiedBackgroundGradient,
        ),
        child: notificationsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _chipGreen),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'common_error'.tr(namedArgs: {'error': '$e'}),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'inbox_notifications_empty'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: ScrollBottomPadding.list(
                context,
                base: const EdgeInsets.symmetric(vertical: 8),
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _NotificationTile(
                  notification: items[index],
                  userId: uid,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({
    required this.notification,
    required this.userId,
  });

  final InAppNotification notification;
  final String? userId;

  IconData _iconForType() {
    switch (notification.type) {
      case 'new_order':
        return Icons.shopping_bag_outlined;
      case 'order_status':
        return Icons.receipt_long_outlined;
      case 'new_product':
        return Icons.storefront_outlined;
      case 'chat_message':
        return Icons.chat_bubble_outline;
      case 'vet_intake':
      case 'vet_response':
        return Icons.medical_services_outlined;
      case 'weather_alert':
        return Icons.cloud_outlined;
      case 'forum_new_topic':
      case 'forum_reply':
        return Icons.forum_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final created = notification.createdAt?.toDate();
    final timeLabel = created == null
        ? ''
        : ChatTimeFormatter.listTime(context, created);
    final body = NotificationLocalization.bodyForInApp(notification);
    final isRead = notification.isRead;
    const chipGreen = NotificationsScreen._chipGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AgroAccentColors.marketplaceCornerRadius,
          ),
          side: BorderSide(
            color: chipGreen.withValues(alpha: isRead ? 0.14 : 0.22),
          ),
        ),
        child: InkWell(
          onTap: () async {
            if (userId != null && !notification.isRead) {
              await ref.read(inAppNotificationRepositoryProvider).markAsRead(
                    userId: userId!,
                    notificationId: notification.id,
                  );
            }

            final intent = notification.navigationTarget != null
                ? notification.toNavigationIntent()
                : null;

            if (context.mounted) {
              Navigator.pop(context);
            }

            if (intent != null) {
              await NotificationService().navigateFromIntent(intent);
            }
          },
          borderRadius: BorderRadius.circular(
            AgroAccentColors.marketplaceCornerRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      isRead ? Colors.grey.shade300 : chipGreen,
                  child: Icon(
                    _iconForType(),
                    color: isRead ? Colors.grey.shade700 : Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        NotificationLocalization.titleForInApp(notification),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.w600 : FontWeight.w700,
                          color: isRead ? Colors.grey.shade800 : chipGreen,
                          fontSize: 15,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (timeLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
