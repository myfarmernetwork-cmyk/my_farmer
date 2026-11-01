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
import '../providers/auth_provider.dart';
import 'product_repository.dart';
import 'chat_repository.dart';

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
      'stockReserved': false,
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
    }

    return grouped.length;
  }

  Stream<List<Order>> watchBuyerOrders(String buyerId) {
    final buyerStream = _firestore
        .collection('orders')
        .where('buyerId', isEqualTo: buyerId)
        .snapshots()
        .map(_sortOrdersNewestFirst);

    final legacyStream = _firestore
        .collection('orders')
        .where('userId', isEqualTo: buyerId)
        .snapshots()
        .map(_sortOrdersNewestFirst);

    return _mergeOrderStreams([buyerStream, legacyStream]);
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

  List<({String productId, double quantity})> _stockEntries(Order order) {
    return order.items
        .where((item) => item.productId.isNotEmpty)
        .map((item) => (productId: item.productId, quantity: item.quantity))
        .toList();
  }

  bool _shouldReserveStockOnAccept(Order order) => order.stockReserved == false;

  bool _shouldRestoreStockOnReject(Order order) {
    if (order.stockReserved == true) return true;
    if (order.stockReserved == null) return true;
    return false;
  }

  Future<void> acceptOrder(Order order) async {
    final payload = <String, dynamic>{
      'status': OrderStatus.preparing,
      'sellerAcceptedAt': FieldValue.serverTimestamp(),
      'paymentStatus': PaymentStatus.pending,
    };

    if (_shouldReserveStockOnAccept(order)) {
      await _productRepository.decreaseStockForOrderItems(_stockEntries(order));
      payload['stockReserved'] = true;
    }

    await _firestore.collection('orders').doc(order.id).update(payload);
  }

  Future<void> rejectOrder({
    required Order order,
    String? message,
  }) async {
    if (_shouldRestoreStockOnReject(order)) {
      await _productRepository.restoreStockForOrderItems(_stockEntries(order));
    }

    final trimmed = message?.trim() ?? '';
    final payload = <String, dynamic>{
      'status': OrderStatus.rejected,
      'rejectedAt': FieldValue.serverTimestamp(),
      'paymentStatus': PaymentStatus.pending,
      if (order.stockReserved == true) 'stockReserved': false,
    };
    if (trimmed.isNotEmpty) {
      payload['sellerMessage'] = trimmed;
    }

    await _firestore.collection('orders').doc(order.id).update(payload);

    if (trimmed.isNotEmpty) {
      await _notifyBuyerInChat(order: order, message: trimmed);
    }
  }

  Future<void> _notifyBuyerInChat({
    required Order order,
    required String message,
  }) async {
    final sellerId = FirebaseAuth.instance.currentUser?.uid;
    if (sellerId == null || order.buyerId.isEmpty) return;

    final chatRepo = ChatRepository();
    final roomId = ChatRepository.roomIdFor(sellerId, order.buyerId);
    final preview = message.length > 80 ? '${message.substring(0, 80)}…' : message;

    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .add({
      'senderId': sellerId,
      'receiverId': order.buyerId,
      'message': message,
      'sourceLanguage': 'hr',
      'messageType': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRepo.touchRoom(
      roomId: roomId,
      senderId: sellerId,
      receiverId: order.buyerId,
      preview: preview,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchBuyerOrderDocs(String buyerId) async {
    final snapshots = await Future.wait([
      _firestore.collection('orders').where('buyerId', isEqualTo: buyerId).get(),
      _firestore.collection('orders').where('userId', isEqualTo: buyerId).get(),
    ]);

    final seen = <String>{};
    final docs = <Map<String, dynamic>>[];
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        if (seen.add(doc.id)) {
          docs.add(doc.data());
        }
      }
    }
    return docs;
  }

  static String _orderSellerIdFrom(Map<String, dynamic> data) =>
      (data['sellerId']?.toString() ?? data['farmerId']?.toString() ?? '')
          .trim();

  static bool _orderAllowsBuyerReview(Map<String, dynamic> data) {
    final status = OrderStatus.normalize(data['status']);
    return OrderStatus.allowsBuyerReview(status);
  }

  /// True when the signed-in buyer has at least one accepted/completed order
  /// from [sellerId] (works for all buyer roles, including company/pharmacy).
  Future<bool> hasCompletedOrderFromSeller(String sellerId) async {
    final user = FirebaseAuth.instance.currentUser;
    final normalizedSellerId = sellerId.trim();
    if (user == null || normalizedSellerId.isEmpty) return false;

    final orders = await _fetchBuyerOrderDocs(user.uid);
    for (final data in orders) {
      if (_orderSellerIdFrom(data) != normalizedSellerId) continue;
      if (_orderAllowsBuyerReview(data)) return true;
    }
    return false;
  }

  /// Translation key explaining why a review is still blocked.
  Future<String> reviewBlockMessageKey(String sellerId) async {
    final user = FirebaseAuth.instance.currentUser;
    final normalizedSellerId = sellerId.trim();
    if (user == null || normalizedSellerId.isEmpty) {
      return 'product_review_purchase_required';
    }

    final orders = await _fetchBuyerOrderDocs(user.uid);
    var hasAnyOrder = false;
    for (final data in orders) {
      if (_orderSellerIdFrom(data) != normalizedSellerId) continue;
      hasAnyOrder = true;
      break;
    }

    return hasAnyOrder
        ? 'product_review_order_pending'
        : 'product_review_purchase_required';
  }
}

final orderRepositoryProvider = Provider((ref) => OrderRepository());

final buyerOrdersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  final uid = ref.watch(currentAuthUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(orderRepositoryProvider).watchBuyerOrders(uid);
});

final sellerOrdersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  final uid = ref.watch(currentAuthUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(orderRepositoryProvider).watchSellerOrders(uid);
});

final adminAllOrdersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  return ref.watch(orderRepositoryProvider).watchAllOrders();
});
