enum SubscriptionTier {
  buyerPremium,
  hobbyFarmerPremium,
  professionalFarmerPremium,
  veterinarianLicense,
  pharmacyLicense,
}

extension SubscriptionTierX on SubscriptionTier {
  String get firestoreValue {
    switch (this) {
      case SubscriptionTier.buyerPremium:
        return 'buyer_premium';
      case SubscriptionTier.hobbyFarmerPremium:
        return 'hobby_farmer_premium';
      case SubscriptionTier.professionalFarmerPremium:
        return 'professional_farmer_premium';
      case SubscriptionTier.veterinarianLicense:
        return 'veterinarian_license';
      case SubscriptionTier.pharmacyLicense:
        return 'pharmacy_license';
    }
  }

  static SubscriptionTier? fromFirestore(String? value) {
    if (value == null) return null;
    for (final tier in SubscriptionTier.values) {
      if (tier.firestoreValue == value) return tier;
    }
    return null;
  }
}
