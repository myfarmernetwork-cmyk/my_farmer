import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/company_catalog_item.dart';
import '../utils/firestore_error_helper.dart';
import '../services/company_catalog_csv_parser.dart';
import '../services/currency_service.dart';
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
    rethrowIfSignedOut();
    return _itemsRef(sellerId)
        .orderBy('name')
        .snapshots()
        .map((snap) {
          final items = <CompanyCatalogItem>[];
          for (final doc in snap.docs) {
            try {
              items.add(CompanyCatalogItem.fromFirestore(doc));
            } catch (_) {
              // Skip corrupt catalog rows.
            }
          }
          return items;
        });
  }

  Future<CompanyCatalogItem?> findBySku({
    required String sellerId,
    required String skuCode,
  }) async {
    rethrowIfSignedOut();
    try {
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
    } on FirebaseException {
      rethrow;
    }
  }

  Future<CatalogImportResult> importCsv({
    required String sellerId,
    required String csvContent,
  }) async {
    rethrowIfSignedOut();
    try {
      final rows = CompanyCatalogCsvParser.parse(csvContent);
      return await importRows(sellerId: sellerId, rows: rows);
    } on FirebaseException {
      rethrow;
    }
  }

  Future<CatalogImportResult> importRows({
    required String sellerId,
    required List<ParsedCatalogRow> rows,
  }) async {
    rethrowIfSignedOut();
    try {
      return await _importRowsImpl(sellerId: sellerId, rows: rows);
    } on FirebaseException {
      rethrow;
    }
  }

  Future<CatalogImportResult> _importRowsImpl({
    required String sellerId,
    required List<ParsedCatalogRow> rows,
  }) async {
    if (rows.isEmpty) {
      return const CatalogImportResult(inserted: 0, updated: 0);
    }

    final userDoc = await _firestore.collection('users').doc(sellerId).get();
    final userData = userDoc.data() ?? {};
    final sellerName = userData['name'] as String? ?? 'Firma';
    final originalCurrency = CurrencyService().resolveSellerCurrencyCode(
      currencyRegion: userData['currencyRegion'] as String?,
    );

    final existingSnap = await _itemsRef(sellerId).get();
    final skuToDocId = <String, String>{};
    final skuToPublishedId = <String, String>{};
    for (final doc in existingSnap.docs) {
      final sku = (doc.data()['skuCode'] as String?)?.trim() ?? '';
      if (sku.isNotEmpty) {
        final skuKey = sku.toLowerCase();
        skuToDocId[skuKey] = doc.id;
        final publishedId =
            (doc.data()['publishedProductId'] as String?)?.trim() ?? '';
        if (publishedId.isNotEmpty) {
          skuToPublishedId[skuKey] = publishedId;
        }
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

    Map<String, dynamic> marketplaceFields(
      ParsedCatalogRow row, {
      required String category,
    }) {
      final trimmedName = row.name.trim();
      return {
        'sellerId': sellerId,
        'sellerName': sellerName,
        'name': trimmedName,
        'description': trimmedName,
        'productDescription': trimmedName,
        'skuCode': row.skuCode.trim(),
        'price': row.price,
        'originalCurrency': originalCurrency,
        'unit': row.unit,
        'category': category,
        'searchTags': ProductUploadService.buildSearchTags(
          role: 'pharmacy',
          categoryId: category,
        ),
        'productionType': 'conventional',
        'isService': false,
        'stock': row.stock,
        'unitDescription': '',
        'isSoldOut': row.stock <= 0,
      };
    }

    for (final row in rows) {
      final category = ProductUploadService.resolveCompanyCategoryForImport(
        rawCategory: row.category,
        productName: row.name,
      );
      final skuKey = row.skuCode.trim().toLowerCase();
      final payload = <String, dynamic>{
        'sellerId': sellerId,
        'skuCode': row.skuCode.trim(),
        'name': row.name.trim(),
        'productDescription': row.name.trim(),
        'price': row.price,
        'stock': row.stock,
        'unit': row.unit,
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final existingId = skuToDocId[skuKey];
      if (existingId != null) {
        batch!.update(_itemsRef(sellerId).doc(existingId), payload);
        updated++;

        final publishedId = skuToPublishedId[skuKey];
        if (publishedId != null) {
          batch!.update(
            _firestore.collection('products').doc(publishedId),
            {
              ...marketplaceFields(row, category: category),
              'catalogItemId': existingId,
            },
          );
          ops += 2;
        } else {
          ops++;
        }
      } else {
        final catalogRef = _itemsRef(sellerId).doc();
        final productRef = _firestore.collection('products').doc();
        batch!.set(catalogRef, {
          ...payload,
          'publishedProductId': productRef.id,
        });
        batch!.set(productRef, {
          ...marketplaceFields(row, category: category),
          'imageUrl': '',
          'catalogItemId': catalogRef.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        skuToDocId[skuKey] = catalogRef.id;
        skuToPublishedId[skuKey] = productRef.id;
        inserted++;
        ops += 2;
      }

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

  /// Nakon ručnog uređivanja objavljenog proizvoda — uskladi katalog firme.
  Future<void> syncCatalogFromProductEdit({
    required String sellerId,
    required String catalogItemId,
    required double price,
    required double stock,
    required String name,
    required String skuCode,
    required String unit,
    required String productDescription,
    required String category,
  }) async {
    final catalogId = catalogItemId.trim();
    if (catalogId.isEmpty) return;

    await _itemsRef(sellerId).doc(catalogId).update(_catalogSyncFields(
      price: price,
      stock: stock,
      name: name,
      skuCode: skuCode,
      unit: unit,
      productDescription: productDescription,
      category: category,
    ));
  }

  /// Fallback kad proizvod nema [catalogItemId], ali je vezan preko publishedProductId.
  Future<void> syncCatalogFromPublishedProduct({
    required String sellerId,
    required String productId,
    required double price,
    required double stock,
    required String name,
    required String skuCode,
    required String unit,
    required String productDescription,
    required String category,
  }) async {
    final snap = await _itemsRef(sellerId)
        .where('publishedProductId', isEqualTo: productId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return;

    await snap.docs.first.reference.update(_catalogSyncFields(
      price: price,
      stock: stock,
      name: name,
      skuCode: skuCode,
      unit: unit,
      productDescription: productDescription,
      category: category,
    ));
  }

  Map<String, dynamic> _catalogSyncFields({
    required double price,
    required double stock,
    required String name,
    required String skuCode,
    required String unit,
    required String productDescription,
    required String category,
  }) {
    return {
      'price': price,
      'stock': stock,
      'name': name.trim(),
      'skuCode': skuCode.trim(),
      'unit': unit,
      'productDescription': productDescription.trim(),
      'category': category,
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
