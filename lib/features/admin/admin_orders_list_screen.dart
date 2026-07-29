import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/order_repository.dart';
import '../../widgets/orders_list_widgets.dart';

/// Admin pregled svih narudžbi i transakcija u sustavu.
class AdminOrdersListScreen extends ConsumerWidget {
  const AdminOrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(adminAllOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sve narudžbe'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => OrdersErrorView(message: '$error'),
        data: (orders) => OrdersListView(
          orders: orders,
          emptyMessage: 'Nema narudžbi u sustavu.',
          isBuyerView: true,
          showCompletedDate: true,
        ),
      ),
    );
  }
}
