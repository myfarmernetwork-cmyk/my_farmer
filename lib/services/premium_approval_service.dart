import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/revenuecat_config.dart';
import '../models/app_user.dart';
import '../models/subscription_tier.dart';

/// Upravljanje Premium odobrenjem za veterinare i tvrtke.
class PremiumApprovalService {
  PremiumApprovalService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static bool requiresAdminApproval(UserRole role) =>
      role == UserRole.veterinarian || role == UserRole.pharmacy;

  static bool requiresAdminApprovalForProduct(String productId) {
    final tier = RevenueCatConfig.tierForProductId(productId);
    return tier == SubscriptionTier.veterinarianLicense ||
        tier == SubscriptionTier.pharmacyLicense;
  }

  Future<void> requestPremiumApproval(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tier = RevenueCatConfig.tierForProductId(productId);
    if (tier == null) return;

    await _firestore.collection('users').doc(user.uid).set(
      {
        'premiumApprovalStatus': 'PENDING',
        'requestedPremiumTier': tier.firestoreValue,
        'premiumRequestedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> activateSubscriptionImmediately(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tier = RevenueCatConfig.tierForProductId(productId);
    if (tier == null) return;

    await _firestore.collection('users').doc(user.uid).set(
      {
        'subscriptionTier': tier.firestoreValue,
        'premiumApprovalStatus': 'APPROVED',
        'requestedPremiumTier': tier.firestoreValue,
        'premiumApprovedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> syncSubscriptionForPurchase({
    required String productId,
    required UserRole role,
  }) async {
    if (requiresAdminApproval(role) ||
        requiresAdminApprovalForProduct(productId)) {
      await requestPremiumApproval(productId);
      return;
    }
    await activateSubscriptionImmediately(productId);
  }
}

final premiumApprovalServiceProvider = Provider<PremiumApprovalService>((ref) {
  return PremiumApprovalService();
});
