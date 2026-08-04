import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/order_repository.dart';
import '../../providers/notification_navigation_provider.dart';
import '../../widgets/notification_context_banner.dart';
import '../../widgets/order_ui_helpers.dart';
import '../../widgets/orders_list_widgets.dart';

class BuyerOrdersScreen extends ConsumerWidget {
  const BuyerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(buyerOrdersProvider);
    final intent = ref.watch(notificationIntentProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('orders_title_buyer'.tr()),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'orders_tab_active'.tr()),
              Tab(text: 'orders_tab_history'.tr()),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (intent?.target == NotificationTarget.buyerOrders)
              const NotificationContextBanner(),
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => OrdersErrorView(message: '$error'),
                data: (orders) => TabBarView(
                  children: [
                    OrdersListView(
                      orders: filterActiveOrders(orders),
                      emptyMessage: 'orders_empty_active'.tr(),
                      isBuyerView: true,
                    ),
                    OrdersListView(
                      orders: filterHistoryOrders(orders),
                      emptyMessage: 'orders_empty_history'.tr(),
                      isBuyerView: true,
                      showCompletedDate: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
