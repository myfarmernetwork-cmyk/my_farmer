import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/order.dart' as app_order;
import '../utils/order_status.dart';

List<app_order.Order> filterActiveOrders(List<app_order.Order> orders) {
  final filtered =
      orders.where((o) => OrderStatus.isActive(o.statusCode)).toList();
  filtered.sort(_compareOrdersNewestFirst);
  return filtered;
}

List<app_order.Order> filterHistoryOrders(List<app_order.Order> orders) {
  final filtered =
      orders.where((o) => OrderStatus.isHistory(o.statusCode)).toList();
  filtered.sort(_compareOrdersNewestFirst);
  return filtered;
}

int _compareOrdersNewestFirst(app_order.Order a, app_order.Order b) {
  final at = a.createdAt;
  final bt = b.createdAt;
  if (at == null && bt == null) return 0;
  if (at == null) return 1;
  if (bt == null) return -1;
  return bt.compareTo(at);
}

String formatOrderDate(BuildContext context, Timestamp? timestamp) {
  if (timestamp == null) return '';
  final locale = context.locale.toString();
  return DateFormat.yMMMd(locale).add_Hm().format(timestamp.toDate());
}

String orderStatusLabel(String statusCode) => OrderStatus.labelKey(statusCode).tr();

Color orderStatusColor(String statusCode) {
  switch (statusCode) {
    case OrderStatus.preparing:
      return Colors.blue;
    case OrderStatus.completed:
      return Colors.green;
    default:
      return Colors.orange;
  }
}

IconData orderStatusIcon(String statusCode) {
  switch (statusCode) {
    case OrderStatus.preparing:
      return Icons.inventory_2_outlined;
    case OrderStatus.completed:
      return Icons.check_circle_outline;
    default:
      return Icons.access_time;
  }
}

Widget orderPaymentBadge(String paymentMethod, {bool prominent = false}) {
  final isStripe = paymentMethod == 'stripe';
  final isGooglePay = paymentMethod == 'google_pay';
  final isDirectPaypal = paymentMethod == 'direct_paypal';
  final isBank = paymentMethod == 'bank_transfer';
  final isPaypal = paymentMethod == 'paypal';
  final label = isStripe
      ? '[${'order_badge_stripe'.tr()}]'
      : isGooglePay
          ? '[${'order_badge_google_pay'.tr()}]'
          : isDirectPaypal
              ? '[${'order_badge_direct_paypal'.tr()}]'
              : isBank
                  ? '[${'order_badge_bank'.tr()}]'
                  : isPaypal
                      ? '[${'order_badge_paypal'.tr()}]'
                      : '[${'order_badge_cash'.tr()}]';
  final bgColor = isStripe
      ? Colors.deepPurple.withValues(alpha: prominent ? 0.14 : 0.08)
      : isGooglePay
          ? Colors.black.withValues(alpha: prominent ? 0.14 : 0.08)
          : isDirectPaypal || isPaypal
              ? const Color(0xFF003087).withValues(alpha: prominent ? 0.14 : 0.08)
              : isBank
                  ? Colors.teal.withValues(alpha: prominent ? 0.14 : 0.08)
                  : Colors.green.withValues(alpha: prominent ? 0.14 : 0.08);
  final borderColor = isStripe
      ? Colors.deepPurple[700]!
      : isGooglePay
          ? Colors.black87
          : isDirectPaypal || isPaypal
              ? const Color(0xFF003087)
              : isBank
                  ? Colors.teal.shade700
                  : Colors.green[700]!;
  final textColor = isStripe
      ? Colors.deepPurple[800]!
      : isGooglePay
          ? Colors.black87
          : isDirectPaypal || isPaypal
              ? const Color(0xFF003087)
              : isBank
                  ? Colors.teal.shade800
                  : Colors.green[800]!;

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: prominent ? 10 : 8,
      vertical: prominent ? 5 : 3,
    ),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor, width: prominent ? 1.5 : 1),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: prominent ? 12 : 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: textColor,
      ),
    ),
  );
}

String orderDeliveryLabel(String deliveryType) =>
    deliveryType == 'delivery'
        ? 'order_delivery_address'.tr()
        : 'order_delivery_pickup'.tr();
