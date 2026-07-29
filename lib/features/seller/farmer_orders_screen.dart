import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/order_repository.dart';
import '../../utils/order_status.dart';
import '../../widgets/order_ui_helpers.dart';
import '../../widgets/orders_list_widgets.dart';

/// Narudžbe farmera / firme — real-time stream iz Firestore.
class FarmerOrdersScreen extends ConsumerWidget {
  const FarmerOrdersScreen({super.key});

  void _changeStatus(
    BuildContext context,
    WidgetRef ref,
    String orderId,
    String statusCode,
  ) {
    if (OrderStatus.isHistory(statusCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('orders_already_delivered'.tr())),
      );
      return;
    }

    final nextCode = OrderStatus.nextCode(statusCode);
    if (nextCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('orders_unknown_status'.tr())),
      );
      return;
    }

    final nextLabel = orderStatusLabel(nextCode);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('orders_change_status_title'.tr()),
        content: Text(
          'orders_change_status_confirm'.tr(namedArgs: {'status': nextLabel}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cart_cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () async {
              await ref
                  .read(orderRepositoryProvider)
                  .updateOrderStatus(orderId, nextCode);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              'orders_confirm'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(sellerOrdersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('orders_title_seller'.tr()),
          backgroundColor: Colors.orange[800],
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
        body: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => OrdersErrorView(message: '$error'),
          data: (orders) => TabBarView(
            children: [
              OrdersListView(
                orders: filterActiveOrders(orders),
                emptyMessage: 'orders_empty_active'.tr(),
                isBuyerView: false,
                onAdvanceStatus: (order) =>
                    _changeStatus(context, ref, order.id, order.statusCode),
              ),
              OrdersListView(
                orders: filterHistoryOrders(orders),
                emptyMessage: 'orders_empty_history'.tr(),
                isBuyerView: false,
                showCompletedDate: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
