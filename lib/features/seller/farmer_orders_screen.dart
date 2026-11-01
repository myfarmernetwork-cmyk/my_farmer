import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../models/farmer_shop_settings.dart';

import '../../models/order.dart';

import '../../providers/notification_navigation_provider.dart';

import '../../widgets/notification_context_banner.dart';

import '../../repositories/order_repository.dart';

import '../../utils/farmer_shop_localization.dart';

import '../../utils/order_status.dart';

import '../../widgets/order_ui_helpers.dart';

import '../../widgets/orders_list_widgets.dart';

import '../../widgets/agro_glass_chrome.dart';

import '../../theme/agro_accent_colors.dart';



/// Narudžbe farmera / firme — real-time stream iz Firestore.

class FarmerOrdersScreen extends ConsumerStatefulWidget {

  const FarmerOrdersScreen({super.key, this.highlightOrderId});



  final String? highlightOrderId;



  @override

  ConsumerState<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();

}



class _FarmerOrdersScreenState extends ConsumerState<FarmerOrdersScreen> {

  String? _highlightOrderId;



  @override

  void initState() {

    super.initState();

    _highlightOrderId = widget.highlightOrderId;

  }



  void _focusOrderFromBanner() {

    final intent = ref.read(notificationIntentProvider);

    final orderId = intent?.orderId;

    if (orderId != null && orderId.isNotEmpty) {

      setState(() => _highlightOrderId = orderId);

    }

    ref.read(notificationIntentProvider.notifier).clear();

  }



  Future<String> _deliveryScheduleForSeller(String sellerId) async {

    if (sellerId.isEmpty) return '—';

    try {

      final doc =

          await FirebaseFirestore.instance.collection('users').doc(sellerId).get();

      final settings = FarmerShopSettings.fromMap(doc.data() ?? {});

      return FarmerShopLocalization.deliveryDays(settings);

    } catch (_) {

      return '—';

    }

  }



  Future<bool?> _confirmDialog({

    required BuildContext context,

    required String title,

    required Widget content,

    required String confirmLabel,

    Color confirmColor = Colors.orange,

  }) {

    return showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: Text(title),

        content: content,

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: Text('cart_cancel'.tr()),

          ),

          ElevatedButton(

            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),

            onPressed: () => Navigator.pop(ctx, true),

            child: Text(

              confirmLabel,

              style: const TextStyle(color: Colors.white),

            ),

          ),

        ],

      ),

    );

  }



  Future<void> _changeStatus(

    BuildContext context,

    WidgetRef ref,

    Order order,

  ) async {

    final statusCode = order.statusCode;

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



    final nextLabel = nextCode == OrderStatus.completed

        ? OrderStatus.completedLabelKey(order.deliveryType).tr()

        : orderStatusLabel(nextCode);



    final firstConfirmed = await _confirmDialog(

      context: context,

      title: 'orders_change_status_title'.tr(),

      content: Column(

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            'orders_change_status_intro'.tr(namedArgs: {'status': nextLabel}),

            style: const TextStyle(fontWeight: FontWeight.w600),

          ),

          const SizedBox(height: 8),

          Text('orders_change_status_confirm'.tr(namedArgs: {'status': nextLabel})),

        ],

      ),

      confirmLabel: 'orders_confirm'.tr(),

    );

    if (firstConfirmed != true || !context.mounted) return;



    if (nextCode == OrderStatus.completed) {

      final schedule = order.deliveryType == 'delivery'

          ? await _deliveryScheduleForSeller(order.sellerId)

          : '—';

      if (!context.mounted) return;



      final previewKey = order.deliveryType == 'delivery'

          ? 'orders_ready_confirm_delivery_body'

          : 'orders_ready_confirm_pickup_body';

      final preview = previewKey.tr(namedArgs: {

        'buyer': order.buyerName,

        'seller': order.sellerName,

        'schedule': schedule,

      });



      final secondConfirmed = await _confirmDialog(

        context: context,

        title: 'orders_ready_confirm_title'.tr(),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(

              'orders_ready_confirm_warning'.tr(),

              style: TextStyle(color: Colors.orange.shade900),

            ),

            const SizedBox(height: 12),

            Text(preview),

            const SizedBox(height: 12),

            Text(

              'orders_ready_confirm_question'.tr(),

              style: const TextStyle(fontWeight: FontWeight.bold),

            ),

          ],

        ),

        confirmLabel: 'orders_confirm'.tr(),

        confirmColor: Colors.green.shade700,

      );

      if (secondConfirmed != true || !context.mounted) return;

    }



    final orderRepo = ref.read(orderRepositoryProvider);
    if (nextCode == OrderStatus.preparing) {
      await orderRepo.acceptOrder(order);
    } else {
      await orderRepo.updateOrderStatus(order.id, nextCode);
    }

    if (!context.mounted) return;



    final snackKey = nextCode == OrderStatus.completed

        ? (order.deliveryType == 'delivery'

            ? 'orders_seller_notify_sent_delivery'

            : 'orders_seller_notify_sent_pickup')

        : null;



    if (snackKey != null) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(snackKey.tr()),

          backgroundColor: Colors.green.shade700,

          duration: const Duration(seconds: 4),

        ),

      );

    }

  }



  Future<void> _rejectOrder(

    BuildContext context,

    WidgetRef ref,

    Order order,

  ) async {

    if (!OrderStatus.canReject(order.statusCode)) return;



    final messageController = TextEditingController();



    final confirmed = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: Text('orders_reject_title'.tr()),

        content: SingleChildScrollView(

          child: Column(

            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              Text('orders_reject_intro'.tr()),

              const SizedBox(height: 12),

              TextField(

                controller: messageController,

                maxLines: 4,

                decoration: InputDecoration(

                  labelText: 'orders_reject_message_label'.tr(),

                  hintText: 'orders_reject_message_hint'.tr(),

                  border: const OutlineInputBorder(),

                ),

              ),

            ],

          ),

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: Text('cart_cancel'.tr()),

          ),

          ElevatedButton(

            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),

            onPressed: () => Navigator.pop(ctx, true),

            child: Text(

              'orders_reject_confirm'.tr(),

              style: const TextStyle(color: Colors.white),

            ),

          ),

        ],

      ),

    );



    if (confirmed != true || !context.mounted) return;



    await ref.read(orderRepositoryProvider).rejectOrder(

      order: order,

      message: messageController.text,

    );

    messageController.dispose();



    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text('orders_reject_success'.tr()),

        backgroundColor: Colors.red.shade700,

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final ordersAsync = ref.watch(sellerOrdersProvider);

    final intent = ref.watch(notificationIntentProvider);



    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AgroAccentColors.marketplaceUnifiedGreen,
        appBar: AgroGlassAppBar(
          unifiedMarketplaceHeader: true,
          title: Text('orders_title_seller'.tr()),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: marketplaceTabBar(
              tabs: [
                Tab(text: 'orders_tab_active'.tr()),
                Tab(text: 'orders_tab_history'.tr()),
              ],
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AgroAccentColors.marketplaceUnifiedBackgroundGradient,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (intent?.target == NotificationTarget.orders)
                  NotificationContextBanner(onOpenOrders: _focusOrderFromBanner),
                Expanded(
                  child: ordersAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AgroAccentColors.marketplaceChipGreen,
                      ),
                    ),
                    error: (error, _) => OrdersErrorView(message: '$error'),
                    data: (orders) => TabBarView(
                      children: [
                        OrdersListView(
                          orders: filterActiveOrders(orders),
                          emptyMessage: 'orders_empty_active'.tr(),
                          isBuyerView: false,
                          highlightOrderId: _highlightOrderId,
                          onAdvanceStatus: (order) =>
                              _changeStatus(context, ref, order),
                          onRejectOrder: (order) =>
                              _rejectOrder(context, ref, order),
                        ),
                        OrdersListView(
                          orders: filterHistoryOrders(orders),
                          emptyMessage: 'orders_empty_history'.tr(),
                          isBuyerView: false,
                          showCompletedDate: true,
                          highlightOrderId: _highlightOrderId,
                        ),
                      ],
                    ),
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


