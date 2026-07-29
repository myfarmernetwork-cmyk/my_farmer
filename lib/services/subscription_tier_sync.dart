import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/revenuecat_config.dart';
import '../models/app_user.dart';
import '../models/subscription_tier.dart';

Future<void> syncSubscriptionTierForProductId(String productId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final tier = RevenueCatConfig.tierForProductId(productId);
  if (tier == null) return;

  await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
    {'subscriptionTier': tier.firestoreValue},
    SetOptions(merge: true),
  );
}

Future<void> syncSubscriptionTierForRole(UserRole role) async {
  final productId = RevenueCatConfig.recommendedProductIdForRole(role);
  await syncSubscriptionTierForProductId(productId);
}

SubscriptionTier tierForRole(UserRole role) {
  switch (role) {
    case UserRole.hobbyFarmer:
      return SubscriptionTier.hobbyFarmerPremium;
    case UserRole.professionalFarmer:
      return SubscriptionTier.professionalFarmerPremium;
    case UserRole.veterinarian:
      return SubscriptionTier.veterinarianLicense;
    case UserRole.pharmacy:
      return SubscriptionTier.pharmacyLicense;
    default:
      return SubscriptionTier.buyerPremium;
  }
}
