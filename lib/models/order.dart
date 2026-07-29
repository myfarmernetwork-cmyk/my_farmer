import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/order_status.dart';
import '../services/currency_service.dart';
import 'payment_result.dart';

class OrderItem {
  final String productId;
  final String name;
  final double price;
  final String originalCurrency;
  final String unit;
  final double quantity;
  final String imageUrl;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    this.originalCurrency = 'BAM',
    this.unit = 'kom',
    this.quantity = 1.0,
    this.imageUrl = '',
  });

  double get lineTotal => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    final rawPrice = data['price'];
    double price = 0;
    if (rawPrice is num) {
      price = rawPrice.toDouble();
    } else if (rawPrice is String) {
      price = double.tryParse(rawPrice) ?? 0;
    }

    return OrderItem(
      productId: data['productId'] ?? data['id'] ?? '',
      name: data['name'] ?? '',
      price: price,
      originalCurrency: CurrencyService.normalizeCode(
        data['originalCurrency'] as String?,
      ),
      unit: data['unit'] as String? ?? 'kom',
      quantity: data['quantity'] is num
          ? (data['quantity'] as num).toDouble()
          : 1.0,
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'originalCurrency': originalCurrency,
      'unit': unit,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }
}

class Order {
  final String id;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final List<OrderItem> items;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String? transactionId;
  final String deliveryType;
  final String status;
  final Timestamp? createdAt;
  final Timestamp? completedAt;

  const Order({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.items,
    required this.total,
    required this.paymentMethod,
    this.paymentStatus = PaymentStatus.pending,
    this.transactionId,
    this.deliveryType = 'pickup',
    required this.status,
    this.createdAt,
    this.completedAt,
  });

  /// Canonical status code for queries, filters and translations.
  String get statusCode => OrderStatus.normalize(status);

  String get deliveryLabel {
    if (deliveryType == 'delivery') return 'delivery';
    return 'pickup';
  }

  String get summaryTitle {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first.name;
    return '${items.first.name} + ${items.length - 1}';
  }

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    List<OrderItem> items;
    if (data['items'] is List && (data['items'] as List).isNotEmpty) {
      items = (data['items'] as List)
          .map((item) => OrderItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } else if (data['productName'] != null) {
      items = [
        OrderItem(
          productId: '',
          name: data['productName'] as String,
          price: _parseDouble(data['totalPrice'] ?? data['total']),
        ),
      ];
    } else {
      items = [];
    }

    final rawTotal = data['total'] ?? data['totalPrice'];
    final total = rawTotal != null
        ? _parseDouble(rawTotal)
        : items.fold(0.0, (sum, item) => sum + item.lineTotal);

    return Order(
      id: doc.id,
      buyerId: data['buyerId'] ?? data['userId'] ?? '',
      buyerName: data['buyerName'] ?? 'Kupac',
      sellerId: data['sellerId'] ?? data['farmerId'] ?? '',
      sellerName: data['sellerName'] ?? data['farmerName'] ?? 'Farmer',
      items: items,
      total: total,
      paymentMethod: _normalizePaymentMethod(data['paymentMethod']),
      paymentStatus: _normalizePaymentStatus(data['paymentStatus']),
      transactionId: data['transactionId']?.toString(),
      deliveryType: data['deliveryType'] as String? ?? 'pickup',
      status: _normalizeStatus(data['status']),
      createdAt: data['createdAt'] as Timestamp?,
      completedAt: data['completedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      if (transactionId != null && transactionId!.isNotEmpty)
        'transactionId': transactionId,
      'deliveryType': deliveryType,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      if (completedAt != null) 'completedAt': completedAt,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String _normalizeStatus(dynamic status) =>
      OrderStatus.normalize(status);

  static String _normalizePaymentMethod(dynamic method) {
    final value = method?.toString().toLowerCase() ?? 'cash';
    if (value.contains('direct_paypal')) return 'direct_paypal';
    if (value.contains('bank_transfer') || value == 'bank') {
      return 'bank_transfer';
    }
    if (value.contains('google_pay') || value.contains('googlepay')) {
      return 'google_pay';
    }
    if (value.contains('stripe') || value.contains('card')) return 'stripe';
    if (value.contains('paypal')) return 'paypal';
    return 'cash';
  }

  static String _normalizePaymentStatus(dynamic status) {
    final value = status?.toString().toUpperCase() ?? PaymentStatus.pending;
    if (value == PaymentStatus.paid) return PaymentStatus.paid;
    if (value == PaymentStatus.failed) return PaymentStatus.failed;
    return PaymentStatus.pending;
  }
}
