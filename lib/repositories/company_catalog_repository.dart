import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/company_catalog_item.dart';
import '../services/company_catalog_csv_parser.dart';
import '../services/product_upload_service.dart';

class CatalogImportResult {
  const CatalogImportResult({
    required this.inserted,
    required this.updated,
  });

  final int inserted;
  final int updated;

  int get total => inserted + updated;
}

class CompanyCatalogRepository {
  CompanyCatalogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _itemsRef(String sellerId) {
    return _firestore
        .collection('company_catalog')
        .doc(sellerId)
        .collection('items');
  }

  Stream<List<CompanyCatalogItem>> watchItems(String sellerId) {
    return _itemsRef(sellerId)
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(CompanyCatalogItem.fromFirestore).toList(),
        );
  }

  Future<CompanyCatalogItem?> findBySku({
    required String sellerId,
    required String skuCode,
  }) async {
    final code = skuCode.trim();
    if (code.isEmpty) return null;

    final exact = await _itemsRef(sellerId)
        .where('skuCode', isEqualTo: code)
        .limit(1)
        .get();
    if (exact.docs.isNotEmpty) {
      return CompanyCatalogItem.fromFirestore(exact.docs.first);
    }

    return null;
  }

  Future<CatalogImportResult> importCsv({
    required String sellerId,
    required String csvContent,
  }) async {
    final rows = CompanyCatalogCsvParser.parse(csvContent);

    final existingSnap = await _itemsRef(sellerId).get();
    final skuToDocId = <String, String>{};
    for (final doc in existingSnap.docs) {
      final sku = (doc.data()['skuCode'] as String?)?.trim() ?? '';
      if (sku.isNotEmpty) {
        skuToDocId[sku.toLowerCase()] = doc.id;
      }
    }

    var inserted = 0;
    var updated = 0;
    WriteBatch? batch = _firestore.batch();
    var ops = 0;

    Future<void> commitIfNeeded({required bool force}) async {
      if (batch == null || ops == 0) return;
      if (!force && ops < 400) return;
      await batch!.commit();
      batch = _firestore.batch();
      ops = 0;
    }

    for (final row in rows) {
      final skuKey = row.skuCode.trim().toLowerCase();
      final payload = <String, dynamic>{
        'sellerId': sellerId,
        'skuCode': row.skuCode.trim(),
        'name': row.name.trim(),
        'productDescription': '',
        'price': row.price,
        'stock': row.stock,
        'unit': row.unit,
        'category': ProductUploadService.companyCategories.first.id,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final existingId = skuToDocId[skuKey];
      if (existingId != null) {
        batch!.update(_itemsRef(sellerId).doc(existingId), payload);
        updated++;
      } else {
        final docRef = _itemsRef(sellerId).doc();
        batch!.set(docRef, payload);
        skuToDocId[skuKey] = docRef.id;
        inserted++;
      }
      ops++;

      await commitIfNeeded(force: false);
    }

    await commitIfNeeded(force: true);

    return CatalogImportResult(inserted: inserted, updated: updated);
  }

  Future<String?> publishToMarketplace({
    required CompanyCatalogItem item,
    required String sellerName,
    required String originalCurrency,
    double? lat,
    double? lng,
  }) async {
    if (item.price <= 0 || item.name.trim().isEmpty) {
      throw Exception('catalog_publish_invalid');
    }

    final payload = <String, dynamic>{
      'sellerId': item.sellerId,
      'sellerName': sellerName,
      'name': item.name.trim(),
      'description': item.productDescription.trim().isNotEmpty
          ? item.productDescription.trim()
          : item.name.trim(),
      'productDescription': item.productDescription.trim().isNotEmpty
          ? item.productDescription.trim()
          : item.name.trim(),
      'skuCode': item.skuCode.trim(),
      'price': item.price,
      'originalCurrency': originalCurrency,
      'unit': item.unit,
      'category': item.category,
      'searchTags': ProductUploadService.buildSearchTags(
        role: 'pharmacy',
        categoryId: item.category,
      ),
      'productionType': 'conventional',
      'isService': false,
      'imageUrl': '',
      'stock': item.stock,
      'unitDescription': '',
      'isSoldOut': item.stock <= 0,
      'catalogItemId': item.id,
      if (lat != null && lng != null)
        'location': {'lat': lat, 'lng': lng},
    };

    String productId;
    if (item.isPublished) {
      productId = item.publishedProductId!;
      await _firestore.collection('products').doc(productId).update(payload);
    } else {
      final doc = await _firestore.collection('products').add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });
      productId = doc.id;
      await _itemsRef(item.sellerId).doc(item.id).set(
        {
          'publishedProductId': productId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    return productId;
  }

  Future<void> syncStockFromProduct({
    required String sellerId,
    required String productId,
    required double newStock,
  }) async {
    final snap = await _itemsRef(sellerId)
        .where('publishedProductId', isEqualTo: productId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return;

    await snap.docs.first.reference.update({
      'stock': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem({
    required String sellerId,
    required String itemId,
  }) async {
    await _itemsRef(sellerId).doc(itemId).delete();
  }
}

final companyCatalogRepositoryProvider =
    Provider<CompanyCatalogRepository>((ref) => CompanyCatalogRepository());
