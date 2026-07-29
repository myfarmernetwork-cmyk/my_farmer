import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/order.dart';
import '../utils/order_status.dart';
import '../utils/quantity_helper.dart';
import 'order_ui_helpers.dart';

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

class OrdersListView extends StatelessWidget {
  final List<Order> orders;
  final String emptyMessage;
  final bool isBuyerView;
  final bool showCompletedDate;
  final void Function(Order order)? onAdvanceStatus;

  const OrdersListView({
    super.key,
    required this.orders,
    required this.emptyMessage,
    required this.isBuyerView,
    this.showCompletedDate = false,
    this.onAdvanceStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
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
              emptyMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCard(
          order: order,
          isBuyerView: isBuyerView,
          showCompletedDate: showCompletedDate,
          onAdvanceStatus: onAdvanceStatus == null
              ? null
              : () => onAdvanceStatus!(order),
        );
      },
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;
  final bool isBuyerView;
  final bool showCompletedDate;
  final VoidCallback? onAdvanceStatus;

  const OrderCard({
    super.key,
    required this.order,
    required this.isBuyerView,
    this.showCompletedDate = false,
    this.onAdvanceStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statusCode = order.statusCode;
    final statusColor = orderStatusColor(statusCode);
    final statusIcon = orderStatusIcon(statusCode);
    final statusLabel = orderStatusLabel(statusCode);
    final completedTs = order.completedAt ?? order.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
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
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[800],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'orders_next_step'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
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
                  '${order.total.toStringAsFixed(2)} KM',
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
            if (isBuyerView) ...[
              const SizedBox(height: 6),
              Text(
                orderDeliveryLabel(order.deliveryType),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
          ],
        ),
      ),
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

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
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
          '${item.lineTotal.toStringAsFixed(2)} KM',
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
