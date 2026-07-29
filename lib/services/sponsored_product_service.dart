import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../models/subscription_tier.dart';

class SponsoredProductService {
  SponsoredProductService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<Product>> fetchSponsoredBelowScan({
    String? plantName,
    int limit = 3,
  }) async {
    final businessSellers = await _fetchBusinessPharmacySellerIds();
    if (businessSellers.isEmpty) return [];

    final snapshot = await _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .get();

    final normalizedPlant = plantName?.trim().toLowerCase() ?? '';
    final matched = snapshot.docs
        .map((doc) => Product.fromFirestore(doc))
        .where((product) {
          if (!businessSellers.contains(product.sellerId)) return false;
          if (!product.isVisibleToBuyers || product.isSoldOut) return false;
          if (normalizedPlant.isEmpty) return true;
          final haystack =
              '${product.name} ${product.description} ${product.category}'
                  .toLowerCase();
          return haystack.contains(normalizedPlant);
        })
        .take(limit)
        .toList();

    if (matched.isNotEmpty) return matched;

    return snapshot.docs
        .map((doc) => Product.fromFirestore(doc))
        .where((product) {
          return businessSellers.contains(product.sellerId) &&
              product.isVisibleToBuyers &&
              !product.isSoldOut;
        })
        .take(limit)
        .toList();
  }

  Future<Set<String>> _fetchBusinessPharmacySellerIds() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'pharmacy')
        .where('premiumApprovalStatus', isEqualTo: 'APPROVED')
        .where('subscriptionTier',
            isEqualTo: SubscriptionTier.pharmacyLicense.firestoreValue)
        .get();

    return snapshot.docs.map((doc) => doc.id).toSet();
  }
}

final sponsoredProductServiceProvider = Provider<SponsoredProductService>((ref) {
  return SponsoredProductService();
});
