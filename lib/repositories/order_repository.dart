import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../models/farmer_shop_settings.dart';
import '../models/order.dart';
import '../models/payment_result.dart';
import '../models/product.dart';
import '../utils/order_status.dart';
import 'product_repository.dart';

class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProductRepository _productRepository = ProductRepository();

  Future<String> _buyerName(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['name'] as String? ?? 'Kupac';
  }

  Future<void> _createOrder({
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required List<OrderItem> items,
    required double total,
    required String paymentMethod,
    String paymentStatus = PaymentStatus.pending,
    String? transactionId,
    String deliveryType = 'pickup',
  }) async {
    await _firestore.collection('orders').add({
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      if (transactionId != null && transactionId.isNotEmpty)
        'transactionId': transactionId,
      'deliveryType': deliveryType,
      'status': OrderStatus.newOrder,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createSingleProductOrder({
    required Product product,
    required String paymentMethod,
    String paymentStatus = PaymentStatus.pending,
    String? transactionId,
    double quantity = 1.0,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Korisnik nije prijavljen');

    final buyerName = await _buyerName(user.uid);
    final normalizedQty = quantity > 0 ? quantity : 1.0;

    await _createOrder(
      buyerId: user.uid,
      buyerName: buyerName,
      sellerId: product.sellerId,
      sellerName: product.sellerName,
      items: [
        OrderItem(
          productId: product.id,
          name: product.name,
          price: product.price,
          originalCurrency: product.originalCurrency,
          unit: product.displayUnit,
          quantity: normalizedQty,
          imageUrl: product.imageUrl,
        ),
      ],
      total: product.price * normalizedQty,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      transactionId: transactionId,
    );

    await _productRepository.decreaseStockForOrderItems([
      (productId: product.id, quantity: normalizedQty),
    ]);
  }

  Future<int> createOrdersFromCart({
    required List<CartItem> items,
    String paymentMethod = 'cash',
    String paymentStatus = PaymentStatus.pending,
    String? transactionId,
    Map<String, DeliveryOption>? deliveryBySeller,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Korisnik nije prijavljen');
    if (items.isEmpty) throw Exception('Korpa je prazna');

    final buyerName = await _buyerName(user.uid);
    final grouped = <String, List<CartItem>>{};

    for (final item in items) {
      grouped.putIfAbsent(item.sellerId, () => []).add(item);
    }

    final stockUpdates = <({String productId, double quantity})>[];

    for (final entry in grouped.entries) {
      final sellerItems = entry.value;
      final total = sellerItems.fold(0.0, (sum, item) => sum + item.lineTotal);

      await _createOrder(
        buyerId: user.uid,
        buyerName: buyerName,
        sellerId: entry.key,
        sellerName: sellerItems.first.sellerName,
        items: sellerItems
            .map(
              (item) => OrderItem(
                productId: item.id,
                name: item.name,
                price: item.price,
                originalCurrency: item.originalCurrency,
                unit: item.unit,
                quantity: item.quantity,
                imageUrl: item.imageUrl,
              ),
            )
            .toList(),
        total: total,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        transactionId: transactionId,
        deliveryType:
            deliveryBySeller?[entry.key]?.firestoreValue ?? 'pickup',
      );

      for (final item in sellerItems) {
        stockUpdates.add((productId: item.id, quantity: item.quantity));
      }
    }

    await _productRepository.decreaseStockForOrderItems(stockUpdates);

    return grouped.length;
  }

  Stream<List<Order>> watchBuyerOrders(String buyerId) {
    return _firestore
        .collection('orders')
        .where('buyerId', isEqualTo: buyerId)
        .snapshots()
        .map(_sortOrdersNewestFirst);
  }

  Stream<List<Order>> watchSellerOrders(String sellerId) {
    final sellerStream = _firestore
        .collection('orders')
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map(_sortOrdersNewestFirst);

    final farmerStream = _firestore
        .collection('orders')
        .where('farmerId', isEqualTo: sellerId)
        .snapshots()
        .map(_sortOrdersNewestFirst);

    return _mergeOrderStreams([sellerStream, farmerStream]);
  }

  Stream<List<Order>> _mergeOrderStreams(List<Stream<List<Order>>> streams) {
    if (streams.isEmpty) return Stream.value(const []);
    if (streams.length == 1) return streams.first;

    final controller = StreamController<List<Order>>.broadcast();
    final latest = List<List<Order>>.generate(streams.length, (_) => const []);
    final subscriptions = <StreamSubscription<List<Order>>>[];

    void emitMerged() {
      final merged = <String, Order>{};
      for (final chunk in latest) {
        for (final order in chunk) {
          merged[order.id] = order;
        }
      }
      final list = merged.values.toList()
        ..sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
      controller.add(list);
    }

    for (var i = 0; i < streams.length; i++) {
      final index = i;
      subscriptions.add(streams[index].listen(
        (orders) {
          latest[index] = orders;
          emitMerged();
        },
        onError: controller.addError,
      ));
    }

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  List<Order> _sortOrdersNewestFirst(QuerySnapshot snap) {
    final orders =
        snap.docs.map((doc) => Order.fromFirestore(doc)).toList();
    orders.sort((a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return orders;
  }

  Stream<List<Order>> watchAllOrders() {
    return _firestore
        .collection('orders')
        .snapshots()
        .map(_sortOrdersNewestFirst);
  }

  Future<void> updateOrderStatus(String orderId, String statusCode) async {
    final normalized = OrderStatus.normalize(statusCode);
    final payload = <String, dynamic>{'status': normalized};
    if (normalized == OrderStatus.completed) {
      payload['completedAt'] = FieldValue.serverTimestamp();
    }
    await _firestore.collection('orders').doc(orderId).update(payload);
  }

  /// True when the signed-in buyer has at least one completed order from [sellerId].
  Future<bool> hasCompletedOrderFromSeller(String sellerId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || sellerId.isEmpty) return false;

    final snapshot = await _firestore
        .collection('orders')
        .where('buyerId', isEqualTo: user.uid)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final orderSellerId =
          data['sellerId']?.toString() ?? data['farmerId']?.toString() ?? '';
      if (orderSellerId != sellerId) continue;
      if (OrderStatus.isHistory(OrderStatus.normalize(data['status']))) {
        return true;
      }
    }
    return false;
  }
}

final orderRepositoryProvider = Provider((ref) => OrderRepository());

final buyerOrdersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(orderRepositoryProvider).watchBuyerOrders(uid);
});

final sellerOrdersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(orderRepositoryProvider).watchSellerOrders(uid);
});

final adminAllOrdersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  return ref.watch(orderRepositoryProvider).watchAllOrders();
});
