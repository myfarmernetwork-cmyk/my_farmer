import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../repositories/order_repository.dart';
import '../utils/order_status.dart';
import '../services/notification_service.dart';

/// Lokalni fallback: obavijest farmeru dok je app otvoren,
/// ako Cloud Function još nije deploy-ovana.
class SellerOrderAlertListener extends ConsumerStatefulWidget {
  final String role;
  final Widget child;

  const SellerOrderAlertListener({
    super.key,
    required this.role,
    required this.child,
  });

  @override
  ConsumerState<SellerOrderAlertListener> createState() =>
      _SellerOrderAlertListenerState();
}

class _SellerOrderAlertListenerState
    extends ConsumerState<SellerOrderAlertListener> {
  final Set<String> _seenOrderIds = {};
  bool _skipInitial = true;

  bool get _isSeller =>
      widget.role == 'hobby_farmer' ||
      widget.role == 'professional_farmer' ||
      widget.role == 'farmer' ||
      widget.role == 'services' ||
      widget.role == 'pharmacy';

  @override
  Widget build(BuildContext context) {
    if (_isSeller) {
      ref.listen<AsyncValue<List<Order>>>(
        sellerOrdersProvider,
        (previous, next) {
          next.whenData(_handleOrdersUpdate);
        },
      );
    }

    return widget.child;
  }

  void _handleOrdersUpdate(List<Order> orders) {
    if (!_isSeller || orders.isEmpty) return;

    if (_skipInitial) {
      for (final order in orders) {
        _seenOrderIds.add(order.id);
      }
      _skipInitial = false;
      return;
    }

    for (final order in orders) {
      if (_seenOrderIds.contains(order.id)) continue;
      if (order.statusCode != OrderStatus.newOrder) continue;

      _seenOrderIds.add(order.id);
      NotificationService().showNewOrderAlert(
        buyerName: order.buyerName,
        summary: order.summaryTitle,
        total: order.total,
        orderId: order.id,
      );
    }
  }
}
