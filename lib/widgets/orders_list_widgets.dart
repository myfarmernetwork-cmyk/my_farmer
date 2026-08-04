import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../services/currency_service.dart';
import '../utils/order_status.dart';
import '../utils/quantity_helper.dart';
import 'order_ui_helpers.dart';
import 'product_price_text.dart';

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
            Text('orders_load_error'.tr()),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
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

  const OrdersListView({
    super.key,
    required this.orders,
    required this.emptyMessage,
    required this.isBuyerView,
    this.showCompletedDate = false,
    this.highlightOrderId,
    this.onAdvanceStatus,
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
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              widget.emptyMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
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
  final Order order;
  final bool isBuyerView;
  final bool showCompletedDate;
  final bool highlighted;
  final VoidCallback? onAdvanceStatus;

  const OrderCard({
    super.key,
    required this.order,
    required this.isBuyerView,
    this.showCompletedDate = false,
    this.highlighted = false,
    this.onAdvanceStatus,
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
    final completedTs = order.completedAt ?? order.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: highlighted
            ? BorderSide(color: Colors.orange.shade700, width: 2)
            : BorderSide.none,
      ),
      color: highlighted ? Colors.orange.shade50 : null,
      elevation: highlighted ? 4 : 2,
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
                      GestureDetector(
                        onTap: onAdvanceStatus,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[800],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (nextActionKey ?? 'orders_next_step').tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (!isBuyerView && stepHint.isNotEmpty) ...[
              const SizedBox(height: 10),
              _OrderFlowSteps(currentCode: statusCode),
              const SizedBox(height: 6),
              Text(
                stepHint.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
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
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              orderDeliveryLabel(order.deliveryType),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (!isBuyerView && order.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'orders_items_title'.tr(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
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
                    color: Colors.green,
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
            if (showCompletedDate && completedTs != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'orders_completed_on'.tr(
                      namedArgs: {
                        'date': formatOrderDate(context, completedTs),
                      },
                    ),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
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
    );
  }
}

class _OrderFlowSteps extends StatelessWidget {
  const _OrderFlowSteps({required this.currentCode});

  final String currentCode;

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
                    ? Colors.orange.shade700
                    : Colors.grey.shade300,
              ),
            ),
          Text(
            OrderStatus.flowStepLabelKey(steps[i]).tr(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: i == currentIndex ? FontWeight.w700 : FontWeight.w500,
              color: i <= currentIndex
                  ? Colors.orange.shade900
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
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 12, color: Colors.grey.shade300),
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
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                quantityLabel,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.green[700],
          ),
        ),
      ],
    );
  }
}
