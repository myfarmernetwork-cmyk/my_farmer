import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/farmer_shop_settings.dart';
import '../models/order.dart';
import '../repositories/order_repository.dart';
import '../utils/farmer_shop_localization.dart';
import '../utils/order_status.dart';

/// Obavijest kupcu u app-u kad farmer promijeni status narudžbe.
class BuyerOrderStatusListener extends ConsumerStatefulWidget {
  const BuyerOrderStatusListener({
    super.key,
    required this.role,
    required this.child,
  });

  final String role;
  final Widget child;

  @override
  ConsumerState<BuyerOrderStatusListener> createState() =>
      _BuyerOrderStatusListenerState();
}

class _BuyerOrderStatusListenerState
    extends ConsumerState<BuyerOrderStatusListener> {
  final Map<String, String> _lastStatusByOrder = {};
  bool _skipInitial = true;

  bool get _isBuyer =>
      widget.role == 'buyer' ||
      widget.role == 'premium_buyer' ||
      widget.role == 'customer';

  @override
  Widget build(BuildContext context) {
    if (_isBuyer) {
      ref.listen<AsyncValue<List<Order>>>(
        buyerOrdersProvider,
        (previous, next) {
          next.whenData(_handleOrdersUpdate);
        },
      );
    }

    return widget.child;
  }

  Future<void> _handleOrdersUpdate(List<Order> orders) async {
    if (!_isBuyer) return;

    if (_skipInitial) {
      for (final order in orders) {
        _lastStatusByOrder[order.id] = order.statusCode;
      }
      _skipInitial = false;
      return;
    }

    for (final order in orders) {
      final previous = _lastStatusByOrder[order.id];
      final current = order.statusCode;
      _lastStatusByOrder[order.id] = current;

      if (previous == null || previous == current) continue;
      if (current != OrderStatus.preparing && current != OrderStatus.completed) {
        continue;
      }

      final message = await _messageForStatus(order, current);
      if (!mounted || message == null) continue;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              current == OrderStatus.completed ? Colors.green[700] : Colors.blue[700],
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<String?> _messageForStatus(Order order, String statusCode) async {
    if (statusCode == OrderStatus.preparing) {
      return 'notification_order_preparing_body'.tr(
        namedArgs: {'seller': order.sellerName},
      );
    }

    if (statusCode == OrderStatus.completed) {
      if (order.deliveryType == 'delivery') {
        final schedule = await _deliverySchedule(order.sellerId);
        return 'notification_order_ready_delivery_body'.tr(
          namedArgs: {'schedule': schedule},
        );
      }
      return 'notification_order_ready_pickup_body'.tr(
        namedArgs: {'seller': order.sellerName},
      );
    }

    return null;
  }

  Future<String> _deliverySchedule(String sellerId) async {
    if (sellerId.isEmpty) return '—';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();
      final settings = FarmerShopSettings.fromMap(doc.data() ?? {});
      return FarmerShopLocalization.deliveryDays(settings);
    } catch (_) {
      return '—';
    }
  }
}
