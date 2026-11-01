import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../repositories/order_repository.dart';

import '../../providers/notification_navigation_provider.dart';

import '../../utils/order_status.dart';

import '../../widgets/notification_context_banner.dart';

import '../../widgets/order_ui_helpers.dart';

import '../../widgets/orders_list_widgets.dart';

import '../../widgets/agro_glass_chrome.dart';

import '../../theme/agro_accent_colors.dart';



class BuyerOrdersScreen extends ConsumerStatefulWidget {

  const BuyerOrdersScreen({

    super.key,

    this.highlightOrderId,

    this.orderStatus,

  });



  final String? highlightOrderId;

  final String? orderStatus;



  @override

  ConsumerState<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();

}



class _BuyerOrdersScreenState extends ConsumerState<BuyerOrdersScreen>

    with SingleTickerProviderStateMixin {

  String? _highlightOrderId;

  late TabController _tabController;



  int _tabIndexForStatus(String? status) {

    final code = OrderStatus.normalize(status);

    return OrderStatus.isHistory(code) ? 1 : 0;

  }



  @override

  void initState() {

    super.initState();

    final intent = ref.read(notificationIntentProvider);

    _highlightOrderId = widget.highlightOrderId ?? intent?.orderId;

    final status = widget.orderStatus ?? intent?.orderStatus;

    _tabController = TabController(

      length: 2,

      vsync: this,

      initialIndex: _tabIndexForStatus(status),

    );

  }



  @override

  void didUpdateWidget(covariant BuyerOrdersScreen oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (widget.highlightOrderId != null &&

        widget.highlightOrderId != oldWidget.highlightOrderId) {

      _highlightOrderId = widget.highlightOrderId;

    }

    if (widget.orderStatus != null &&

        widget.orderStatus != oldWidget.orderStatus) {

      _tabController.animateTo(_tabIndexForStatus(widget.orderStatus));

    }

  }



  @override

  void dispose() {

    _tabController.dispose();

    super.dispose();

  }



  void _focusOrderFromBanner() {

    final intent = ref.read(notificationIntentProvider);

    final orderId = intent?.orderId;

    if (orderId != null && orderId.isNotEmpty) {

      setState(() => _highlightOrderId = orderId);

    }

    _tabController.animateTo(_tabIndexForStatus(intent?.orderStatus));

    ref.read(notificationIntentProvider.notifier).clear();

  }



  @override

  Widget build(BuildContext context) {

    final ordersAsync = ref.watch(buyerOrdersProvider);

    final intent = ref.watch(notificationIntentProvider);



    return MarketplaceScreenScaffold(

      title: Text('orders_title_buyer'.tr()),

      bottom: PreferredSize(

        preferredSize: const Size.fromHeight(48),

        child: marketplaceTabBar(

          controller: _tabController,

          tabs: [

            Tab(text: 'orders_tab_active'.tr()),

            Tab(text: 'orders_tab_history'.tr()),

          ],

        ),

      ),

      body: SafeArea(

        top: false,

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            if (intent?.target == NotificationTarget.buyerOrders)

              NotificationContextBanner(onOpenOrders: _focusOrderFromBanner),

            Expanded(

              child: ordersAsync.when(

                loading: () => Center(

                  child: CircularProgressIndicator(

                    color: AgroAccentColors.marketplaceChipGreen,

                  ),

                ),

                error: (error, _) => OrdersErrorView(message: '$error'),

                data: (orders) => TabBarView(

                  controller: _tabController,

                  children: [

                    OrdersListView(

                      orders: filterActiveOrders(orders),

                      emptyMessage: 'orders_empty_active'.tr(),

                      isBuyerView: true,

                      highlightOrderId: _highlightOrderId,

                    ),

                    OrdersListView(

                      orders: filterHistoryOrders(orders),

                      emptyMessage: 'orders_empty_history'.tr(),

                      isBuyerView: true,

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

    );

  }

}


