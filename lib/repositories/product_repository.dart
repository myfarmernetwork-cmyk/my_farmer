import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/buyer/storefront_seller_data.dart';
import '../models/company_catalog_item.dart';
import '../models/product.dart';
import '../utils/firestore_error_helper.dart';
import 'company_catalog_repository.dart';
import '../services/notification_service.dart';

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CompanyCatalogRepository _catalogRepository = CompanyCatalogRepository();

  // Dohvati sve proizvode
  Stream<List<Product>> getProducts({bool buyerView = true}) {
    return _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => _mapAndSyncProducts(snap, buyerView: buyerView));
  }

  // Dohvati proizvode od jednog farmera
  Stream<List<Product>> getProductsBySeller(
    String sellerId, {
    bool buyerView = true,
  }) {
    return _firestore
        .collection('products')
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .handleError(_rethrowNormalizedFirestoreError)
        .map((snap) => _mapAndSyncProducts(snap, buyerView: buyerView));
  }

  /// Company catalog for pharmacy / company storefronts (`company_catalog` collection).
  Stream<List<CompanyCatalogItem>> getCompanyCatalogBySeller(String sellerId) {
    return _firestore
        .collection('company_catalog')
        .doc(sellerId)
        .collection('items')
        .snapshots()
        .handleError(_rethrowNormalizedFirestoreError)
        .map((snap) {
          final items = <CompanyCatalogItem>[];
          for (final doc in snap.docs) {
            try {
              items.add(CompanyCatalogItem.fromFirestore(doc));
            } catch (_) {
              // Skip corrupt catalog rows — one bad record must not break a profile.
            }
          }
          items.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return items;
        });
  }

  // Dohvati PayPal email farmera
  Future<String?> getSellerPaypalEmail(String sellerId) async {
    final doc =
        await _firestore.collection('users').doc(sellerId).get();
    final legacy = doc.data()?['paypalEmail'] as String?;
    if (legacy != null && legacy.trim().isNotEmpty) {
      return legacy.trim();
    }

    final methods = await _firestore
        .collection('users')
        .doc(sellerId)
        .collection('payment_methods')
        .where('type', isEqualTo: 'paypal')
        .limit(1)
        .get();
    if (methods.docs.isEmpty) return null;
    return methods.docs.first.data()['paypalEmail']?.toString();
  }

  // Dohvati podatke o farmeru (`users` collection).
  Future<Map<String, dynamic>?> getSellerData(String sellerId) async {
    final id = sellerId.trim();
    if (id.isEmpty) return null;

    try {
      final doc = await _firestore.collection('users').doc(id).get();
      if (!doc.exists) return null;
      final raw = doc.data();
      if (raw == null) return null;
      return StorefrontSellerData.normalizeSellerProfileMap(raw);
    } on FirestoreNotSignedInException {
      rethrow;
    } on FirebaseException {
      rethrow;
    } catch (e) {
      throw _normalizeFirestoreError(e);
    }
  }

  Never _rethrowNormalizedFirestoreError(Object error, StackTrace stack) {
    Error.throwWithStackTrace(_normalizeFirestoreError(error), stack);
  }

  FirebaseException _normalizeFirestoreError(Object error) {
    if (error is FirebaseException) return error;

    final raw = error.toString().toLowerCase();
    if (raw.contains('permission-denied') || raw.contains('permission denied')) {
      return FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: error.toString(),
      );
    }
    if (raw.contains('unauthenticated') || raw.contains('auth == null')) {
      return FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: error.toString(),
      );
    }

    return FirebaseException(
      plugin: 'cloud_firestore',
      code: 'load-failed',
      message: error.toString(),
    );
  }

  Future<void> updateSoldOut({
    required String productId,
    required bool isSoldOut,
  }) async {
    await _firestore.collection('products').doc(productId).update({
      'isSoldOut': isSoldOut,
    });
  }

  Future<void> ensureHarvestTransition(Product product) async {
    if (!product.needsHarvestTransition) return;

    await _firestore.collection('products').doc(product.id).update({
      'requiresFinalPhoto': true,
    });
  }

  Future<void> updateHarvestSchedule({
    required String productId,
    required DateTime harvestDateTime,
    String? imageUrl,
  }) async {
    final payload = <String, dynamic>{
      'harvestDateTime': Timestamp.fromDate(harvestDateTime),
      'isUpcoming': true,
      'requiresFinalPhoto': false,
    };
    if (imageUrl != null && imageUrl.isNotEmpty) {
      payload['imageUrl'] = imageUrl;
    }
    await _firestore.collection('products').doc(productId).update(payload);
  }

  Future<void> completeHarvest(String productId) async {
    await _firestore.collection('products').doc(productId).update({
      'requiresFinalPhoto': true,
    });
  }

  Future<void> publishFinalHarvestPhoto({
    required String productId,
    required String imageUrl,
  }) async {
    await _firestore.collection('products').doc(productId).update({
      'imageUrl': imageUrl,
      'isUpcoming': false,
      'requiresFinalPhoto': false,
    });
  }

  List<Product> _mapAndSyncProducts(
    QuerySnapshot snap, {
    bool buyerView = false,
  }) {
    final products = <Product>[];
    for (final doc in snap.docs) {
      try {
        products.add(Product.fromFirestore(doc));
      } catch (_) {
        // Skip corrupt product docs — one bad record must not break a profile.
      }
    }

    for (final product in products) {
      if (product.needsHarvestTransition) {
        ensureHarvestTransition(product);
      }
    }

    if (!buyerView) return products;

    return products.where((product) => product.isVisibleToBuyers).toList();
  }

  Future<Map<String, Product>> fetchProductsByIds(Set<String> productIds) async {
    if (productIds.isEmpty) return {};

    final result = <String, Product>{};
    final ids = productIds.toList();

    for (var i = 0; i < ids.length; i += 10) {
      final end = (i + 10 > ids.length) ? ids.length : i + 10;
      final chunk = ids.sublist(i, end);
      final snapshot = await _firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        try {
          result[doc.id] = Product.fromFirestore(doc);
        } catch (_) {
          // Skip corrupt product docs.
        }
      }
    }

    return result;
  }

  Future<void> decreaseStockForOrderItems(
    List<({String productId, double quantity})> items,
  ) async {
    for (final entry in items) {
      if (entry.productId.isEmpty || entry.quantity <= 0) continue;

      final docRef = _firestore.collection('products').doc(entry.productId);
      String sellerId = '';
      String productName = 'Proizvod';
      double nextStock = 0;

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Product ${entry.productId} not found');
        }

        final data = snapshot.data() ?? {};
        final isSoldOut = data['isSoldOut'] as bool? ?? false;
        final currentStock = data['stock'] is num
            ? (data['stock'] as num).toDouble()
            : 999.0;

        if (isSoldOut || currentStock < entry.quantity) {
          throw Exception(
            'Insufficient stock for product ${entry.productId}',
          );
        }

        nextStock =
            (currentStock - entry.quantity).clamp(0.0, double.infinity);
        sellerId = data['sellerId'] as String? ?? '';
        productName = data['name'] as String? ?? 'Proizvod';

        transaction.update(docRef, {
          'stock': nextStock,
          if (nextStock <= 0) 'isSoldOut': true,
        });
      });

      if (sellerId.isNotEmpty) {
        try {
          await _catalogRepository.syncStockFromProduct(
            sellerId: sellerId,
            productId: entry.productId,
            newStock: nextStock,
          );
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied') rethrow;
        }
        if (nextStock > 0 && nextStock <= 10) {
          await NotificationService().showLowStockAlert(
            productName: productName,
            stock: nextStock,
            productId: entry.productId,
          );
        }
      }
    }
  }
}

final productRepositoryProvider = Provider((ref) => ProductRepository());