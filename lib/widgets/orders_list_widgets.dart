import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../models/payment_result.dart';
import '../services/currency_service.dart';
import '../utils/order_status.dart';
import '../utils/quantity_helper.dart';
import '../utils/scroll_bottom_padding.dart';
import 'order_ui_helpers.dart';
import 'navigate_to_farmer_button.dart';
import 'farmer_review_prompt.dart';
import 'product_price_text.dart';
import '../theme/agro_accent_colors.dart';

class OrdersErrorView extends StatelessWidget {
  final String message;

  const OrdersErrorView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(
              'orders_load_error'.tr(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrdersListView extends StatefulWidget {
  final List<Order> orders;
  final String emptyMessage;
  final bool isBuyerView;
  final bool showCompletedDate;
  final String? highlightOrderId;
  final void Function(Order order)? onAdvanceStatus;
  final void Function(Order order)? onRejectOrder;

  const OrdersListView({
    super.key,
    required this.orders,
    required this.emptyMessage,
    required this.isBuyerView,
    this.showCompletedDate = false,
    this.highlightOrderId,
    this.onAdvanceStatus,
    this.onRejectOrder,
  });

  @override
  State<OrdersListView> createState() => _OrdersListViewState();
}

class _OrdersListViewState extends State<OrdersListView> {
  final GlobalKey _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scheduleScrollToHighlight();
  }

  @override
  void didUpdateWidget(covariant OrdersListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightOrderId != widget.highlightOrderId ||
        oldWidget.orders.length != widget.orders.length) {
      _scheduleScrollToHighlight();
    }
  }

  void _scheduleScrollToHighlight() {
    if (widget.highlightOrderId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _highlightKey.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        alignment: 0.15,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 70,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              widget.emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ScrollBottomPadding.list(context),
      itemCount: widget.orders.length,
      itemBuilder: (context, index) {
        final order = widget.orders[index];
        final highlighted =
            widget.highlightOrderId != null && order.id == widget.highlightOrderId;
        final card = OrderCard(
          order: order,
          isBuyerView: widget.isBuyerView,
          showCompletedDate: widget.showCompletedDate,
          highlighted: highlighted,
          onAdvanceStatus: widget.onAdvanceStatus == null
              ? null
              : () => widget.onAdvanceStatus!(order),
          onRejectOrder: widget.onRejectOrder == null
              ? null
              : () => widget.onRejectOrder!(order),
        );
        if (!highlighted) return card;
        return KeyedSubtree(
          key: _highlightKey,
          child: card,
        );
      },
    );
  }
}

class OrderCard extends ConsumerWidget {
  static const _chipGreen = AgroAccentColors.marketplaceChipGreen;
  static const _priceYellow = Color(0xFFFFEB3B);

  final Order order;
  final bool isBuyerView;
  final bool showCompletedDate;
  final bool highlighted;
  final VoidCallback? onAdvanceStatus;
  final VoidCallback? onRejectOrder;

  const OrderCard({
    super.key,
    required this.order,
    required this.isBuyerView,
    this.showCompletedDate = false,
    this.highlighted = false,
    this.onAdvanceStatus,
    this.onRejectOrder,
  });

  String _orderOriginalCurrency() {
    if (order.items.isEmpty) return CurrencyService.bam;
    return order.items.first.originalCurrency;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusCode = order.statusCode;
    final statusColor = orderStatusColor(statusCode);
    final statusIcon = orderStatusIcon(statusCode);
    final statusLabel = orderStatusLabel(
      statusCode,
      deliveryType: order.deliveryType,
    );
    final stepHint = !isBuyerView && OrderStatus.isActive(statusCode)
        ? OrderStatus.sellerHintKey(statusCode)
        : '';
    final nextActionKey = onAdvanceStatus != null && OrderStatus.isActive(statusCode)
        ? OrderStatus.nextActionLabelKey(statusCode, order.deliveryType)
        : null;
    final completedTs = order.completedAt;

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
            color: highlighted
                ? Colors.orange.shade400
                : _chipGreen.withValues(alpha: 0.22),
            width: highlighted ? 1.8 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.summaryTitle.isEmpty
                      ? 'order_summary_label'.tr()
                      : order.summaryTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _chipGreen,
                  ),
                ),
              ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onAdvanceStatus != null &&
                        OrderStatus.isActive(statusCode)) ...[
                      const SizedBox(height: 8),
                      if (OrderStatus.canReject(statusCode) &&
                          onRejectOrder != null)
                        GestureDetector(
                          onTap: onRejectOrder,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'orders_action_reject'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (OrderStatus.canReject(statusCode) &&
                          onRejectOrder != null)
                        const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onAdvanceStatus,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _chipGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (nextActionKey ?? 'orders_next_step').tr(),
                            style: const TextStyle(
                              color: _priceYellow,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (order.createdAt != null) ...[
              const SizedBox(height: 8),
              orderTimestampRow(
                context: context,
                timestamp: order.createdAt,
                labelKey: orderCreatedLabelKey(isBuyerView: isBuyerView),
              ),
            ],
            if (!isBuyerView && stepHint.isNotEmpty) ...[
              const SizedBox(height: 10),
              _OrderFlowSteps(currentCode: statusCode),
              const SizedBox(height: 6),
              Text(
                stepHint.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
            ],
            if (isBuyerView && order.items.length > 1) ...[
              const SizedBox(height: 6),
              Text(
                'orders_products_count'.tr(
                  namedArgs: {'count': '${order.items.length}'},
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (!isBuyerView) ...[
                  orderPaymentBadge(
                    order.paymentMethod,
                    prominent: true,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    isBuyerView
                        ? 'orders_farmer_label'.tr(
                            namedArgs: {'name': order.sellerName},
                          )
                        : 'orders_buyer_label'.tr(
                            namedArgs: {'name': order.buyerName},
                          ),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              orderDeliveryLabel(order.deliveryType),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            if (OrderNavigateToFarmerButton.shouldShow(
              order,
              isBuyerView: isBuyerView,
            )) ...[
              const SizedBox(height: 10),
              OrderNavigateToFarmerButton(order: order),
            ],
            if (!isBuyerView && order.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'orders_items_title'.tr(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _chipGreen,
                ),
              ),
              const SizedBox(height: 6),
              OrderItemsList(items: order.items),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  ProductPriceText.formatAmountOnly(
                    context,
                    ref,
                    order.total,
                    originalCurrency: _orderOriginalCurrency(),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    color: _chipGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isBuyerView) ...[
                  const SizedBox(width: 10),
                  orderPaymentBadge(order.paymentMethod),
                ],
              ],
            ),
            if (isBuyerView && statusCode == OrderStatus.completed) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  order.deliveryType == 'delivery'
                      ? 'notification_order_ready_delivery_body'.tr(
                          namedArgs: {'schedule': '—'},
                        )
                      : 'notification_order_ready_pickup_body'.tr(
                          namedArgs: {'seller': order.sellerName},
                        ),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (isBuyerView && OrderStatus.allowsBuyerReview(statusCode)) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showFarmerReviewPrompt(
                    context,
                    ref,
                    sellerId: order.sellerId,
                  ),
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: Text('product_rate_farmer'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _chipGreen,
                    side: const BorderSide(color: _chipGreen),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
            if (order.sellerMessage != null &&
                order.sellerMessage!.trim().isNotEmpty &&
                statusCode == OrderStatus.rejected) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  order.sellerMessage!.trim(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade900,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            if (!isBuyerView &&
                statusCode == OrderStatus.newOrder &&
                order.paymentStatus == PaymentStatus.pending) ...[
              const SizedBox(height: 8),
              Text(
                'orders_payment_after_accept'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (isBuyerView && statusCode == OrderStatus.newOrder) ...[
              const SizedBox(height: 8),
              Text(
                'orders_buyer_waiting_accept'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (isBuyerView &&
                statusCode == OrderStatus.preparing &&
                order.paymentStatus == PaymentStatus.pending) ...[
              const SizedBox(height: 8),
              Text(
                'orders_buyer_pay_after_accept'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (showCompletedDate &&
                statusCode == OrderStatus.completed &&
                completedTs != null) ...[
              const SizedBox(height: 6),
              orderTimestampRow(
                context: context,
                timestamp: completedTs,
                labelKey: 'orders_completed_on',
              ),
            ],
            if (showCompletedDate &&
                statusCode == OrderStatus.rejected &&
                order.rejectedAt != null) ...[
              const SizedBox(height: 6),
              orderTimestampRow(
                context: context,
                timestamp: order.rejectedAt,
                labelKey: 'orders_rejected_on',
              ),
            ],
            if (!isBuyerView && statusCode == OrderStatus.completed) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.deliveryType == 'delivery'
                            ? 'orders_seller_notify_sent_delivery'.tr()
                            : 'orders_seller_notify_sent_pickup'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

class _OrderFlowSteps extends StatelessWidget {
  const _OrderFlowSteps({required this.currentCode});

  final String currentCode;

  static const _chipGreen = OrderCard._chipGreen;

  @override
  Widget build(BuildContext context) {
    final steps = OrderStatus.flow;
    final currentIndex = steps.indexOf(currentCode);

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= currentIndex
                    ? _chipGreen.withValues(alpha: 0.45)
                    : Colors.grey.shade300,
              ),
            ),
          Text(
            OrderStatus.flowStepLabelKey(steps[i]).tr(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: i == currentIndex ? FontWeight.w700 : FontWeight.w500,
              color: i <= currentIndex
                  ? _chipGreen
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ],
    );
  }
}

class OrderItemsList extends StatelessWidget {
  const OrderItemsList({super.key, required this.items});

  final List<OrderItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 12,
                color: Colors.grey.shade300,
              ),
            _OrderItemRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _OrderItemRow extends ConsumerWidget {
  const _OrderItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantityLabel =
        QuantityHelper.formatWithUnit(item.quantity, item.unit);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: OrderCard._chipGreen,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                quantityLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ProductPriceText.formatAmountOnly(
            context,
            ref,
            item.lineTotal,
            originalCurrency: item.originalCurrency,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: OrderCard._chipGreen,
          ),
        ),
      ],
    );
  }
}
