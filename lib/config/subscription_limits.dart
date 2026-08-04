import '../models/app_user.dart';
import '../models/subscription_tier.dart';

/// Službeni poslovni model — izvor istine za limite po ulozi i pretplati.
class SubscriptionLimits {
  SubscriptionLimits._();

  static const int introAiScansTotal = 1;

  static const int buyerPremiumMonthlyScans = 15;
  static const int hobbyPremiumMonthlyScans = 30;
  static const int proPremiumMonthlyScans = 60;

  static const int hobbyMaxActiveProducts = 5;
  static const int proMaxActiveProducts = 9999;
  static const int companyFreeMaxActiveProducts = 5;
  static const int companyBusinessMaxActiveProducts = 9999;
  static const int vetFreeMaxActiveProducts = 5;
  static const int vetPremiumMaxActiveProducts = 9999;

  static const int buyerFreeMaxAnimals = 3;
  static const int buyerPremiumMaxAnimals = 10;
  static const int hobbyFreeMaxAnimals = 5;
  static const int hobbyPremiumMaxAnimals = 20;
  static const int proFreeMaxAnimals = 20;
  static const int proPremiumMaxAnimals = 500;
  static const int vetPremiumMaxPrivatePets = 10;

  static const int farmerFreeMaxParcels = 1;
  static const int hobbyPremiumMaxParcels = 5;
  static const int proPremiumMaxParcels = 50;

  static const int proPremiumNirsMonthlyLoads = 50;
  /// Hobi — manje od Pro-a (usputni poljoprivrednici, ne puni posao).
  static const int hobbyPremiumNirsMonthlyLoads = 20;

  static double monthlyPriceEur(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.buyerPremium:
        return 1.99;
      case SubscriptionTier.hobbyFarmerPremium:
        return 3.99;
      case SubscriptionTier.professionalFarmerPremium:
        return 9.99;
      case SubscriptionTier.veterinarianLicense:
        return 9.99;
      case SubscriptionTier.pharmacyLicense:
        return 19.99;
    }
  }

  static int monthlyScansForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.buyerPremium:
        return buyerPremiumMonthlyScans;
      case SubscriptionTier.hobbyFarmerPremium:
        return hobbyPremiumMonthlyScans;
      case SubscriptionTier.professionalFarmerPremium:
        return proPremiumMonthlyScans;
      case SubscriptionTier.veterinarianLicense:
        return 50;
      case SubscriptionTier.pharmacyLicense:
        return 100;
    }
  }

  static int maxProductSlots({
    required UserRole role,
    SubscriptionTier? tier,
    bool hasPaidBusiness = false,
    bool hasVetPremium = false,
  }) {
    switch (role) {
      case UserRole.hobbyFarmer:
        return hobbyMaxActiveProducts;
      case UserRole.professionalFarmer:
        return proMaxActiveProducts;
      case UserRole.veterinarian:
        if (hasVetPremium && tier == SubscriptionTier.veterinarianLicense) {
          return vetPremiumMaxActiveProducts;
        }
        return vetFreeMaxActiveProducts;
      case UserRole.pharmacy:
        if (hasPaidBusiness && tier == SubscriptionTier.pharmacyLicense) {
          return companyBusinessMaxActiveProducts;
        }
        return companyFreeMaxActiveProducts;
      default:
        return 0;
    }
  }

  static int maxAnimals({
    required UserRole role,
    SubscriptionTier? tier,
    required bool hasPaidPremium,
  }) {
    switch (role) {
      case UserRole.buyer:
        if (hasPaidPremium && tier == SubscriptionTier.buyerPremium) {
          return buyerPremiumMaxAnimals;
        }
        return buyerFreeMaxAnimals;
      case UserRole.hobbyFarmer:
        if (hasPaidPremium &&
            (tier == SubscriptionTier.hobbyFarmerPremium ||
                tier == SubscriptionTier.professionalFarmerPremium)) {
          return hobbyPremiumMaxAnimals;
        }
        return hobbyFreeMaxAnimals;
      case UserRole.professionalFarmer:
        if (hasPaidPremium && tier == SubscriptionTier.professionalFarmerPremium) {
          return proPremiumMaxAnimals;
        }
        return proFreeMaxAnimals;
      case UserRole.veterinarian:
        if (hasPaidPremium && tier == SubscriptionTier.veterinarianLicense) {
          return vetPremiumMaxPrivatePets;
        }
        return 0;
      default:
        return 0;
    }
  }

  /// Ukupno spremljenih parcela u bazi (crtanje bez NIRS-a).
  static int maxSavedParcels({
    required UserRole role,
    SubscriptionTier? tier,
    required bool hasPaidPremium,
  }) {
    if (role != UserRole.hobbyFarmer && role != UserRole.professionalFarmer) {
      return 0;
    }
    if (role == UserRole.professionalFarmer &&
        tier == SubscriptionTier.professionalFarmerPremium) {
      return proPremiumMaxParcels;
    }
    if (role == UserRole.hobbyFarmer &&
        tier == SubscriptionTier.hobbyFarmerPremium) {
      return hobbyPremiumMaxParcels;
    }
    return farmerFreeMaxParcels;
  }

  static bool canAccessLandMeasurement(UserRole role) =>
      role == UserRole.hobbyFarmer || role == UserRole.professionalFarmer;

  static int monthlyNirsLoadsForTier({
    required UserRole role,
    SubscriptionTier? tier,
    required bool hasPaidPremium,
  }) {
    if (!hasPaidPremium || tier == null) return 0;
    if (role == UserRole.professionalFarmer &&
        tier == SubscriptionTier.professionalFarmerPremium) {
      return proPremiumNirsMonthlyLoads;
    }
    if (role == UserRole.hobbyFarmer &&
        tier == SubscriptionTier.hobbyFarmerPremium) {
      return hobbyPremiumNirsMonthlyLoads;
    }
    return 0;
  }

  static bool canUseNirsMonitoring({
    required UserRole role,
    SubscriptionTier? tier,
    required bool hasPaidPremium,
  }) {
    return monthlyNirsLoadsForTier(
          role: role,
          tier: tier,
          hasPaidPremium: hasPaidPremium,
        ) >
        0;
  }

  /// Rezervacija robe u dolasku u košarici (kupac / hobi premium).
  static bool canReserveUpcomingInCart({
    required UserRole role,
    SubscriptionTier? tier,
    required bool hasPaidPremium,
  }) {
    if (!hasPaidPremium || tier == null) return false;
    switch (role) {
      case UserRole.buyer:
        return tier == SubscriptionTier.buyerPremium;
      case UserRole.hobbyFarmer:
        return tier == SubscriptionTier.hobbyFarmerPremium ||
            tier == SubscriptionTier.professionalFarmerPremium;
      case UserRole.professionalFarmer:
        return tier == SubscriptionTier.professionalFarmerPremium;
      default:
        return false;
    }
  }

  static bool canSellOnMarketplace(UserRole role) =>
      role == UserRole.hobbyFarmer ||
      role == UserRole.professionalFarmer ||
      role == UserRole.veterinarian ||
      role == UserRole.pharmacy;

  static bool buyerCanPurchaseWithoutPremium(UserRole role) =>
      role == UserRole.buyer || role == UserRole.pharmacy;

  static bool isPremiumVeterinarian(SubscriptionTier? tier) =>
      tier == SubscriptionTier.veterinarianLicense;

  static bool hasBusinessLicense(SubscriptionTier? tier) =>
      tier == SubscriptionTier.pharmacyLicense;

  static bool vetAppearsInProximityRadar({
    required UserRole role,
    SubscriptionTier? tier,
    required bool isPremiumApproved,
  }) {
    return role == UserRole.veterinarian &&
        isPremiumApproved &&
        tier == SubscriptionTier.veterinarianLicense;
  }

  static bool vetHasPatientRecords({
    required UserRole role,
    SubscriptionTier? tier,
    required bool isPremiumApproved,
  }) {
    return vetAppearsInProximityRadar(
      role: role,
      tier: tier,
      isPremiumApproved: isPremiumApproved,
    );
  }

  static bool sellerHasMarketplaceBoost({
    required UserRole role,
    SubscriptionTier? tier,
  }) {
    return role == UserRole.pharmacy && hasBusinessLicense(tier);
  }
}
