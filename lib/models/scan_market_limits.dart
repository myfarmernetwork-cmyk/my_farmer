import '../models/app_user.dart';
import '../models/subscription_tier.dart';

enum ScanMarket {
  balkanEuro,
  asian,
  african,
}

class ScanMarketLimits {
  static ScanMarket fromLanguageCode(String? code) {
    switch (code?.split('_').first) {
      case 'zh':
      case 'hi':
      case 'id':
        return ScanMarket.asian;
      case 'sw':
      case 'ar':
        return ScanMarket.african;
      default:
        return ScanMarket.balkanEuro;
    }
  }

  static const businessPromoMonthlyLimit = 3;

  static int buyerLimit(ScanMarket market) {
    switch (market) {
      case ScanMarket.balkanEuro:
        return 10;
      case ScanMarket.asian:
        return 12;
      case ScanMarket.african:
        return 8;
    }
  }

  static int hobbyLimit(ScanMarket market) {
    switch (market) {
      case ScanMarket.balkanEuro:
        return 15;
      case ScanMarket.asian:
        return 25;
      case ScanMarket.african:
        return 18;
    }
  }

  static int professionalLimit(ScanMarket market) {
    switch (market) {
      case ScanMarket.balkanEuro:
        return 30;
      case ScanMarket.asian:
        return 40;
      case ScanMarket.african:
        return 28;
    }
  }

  static int limitForTier(SubscriptionTier tier, ScanMarket market) {
    switch (tier) {
      case SubscriptionTier.buyerPremium:
        return buyerLimit(market);
      case SubscriptionTier.hobbyFarmerPremium:
        return hobbyLimit(market);
      case SubscriptionTier.professionalFarmerPremium:
        return professionalLimit(market);
      case SubscriptionTier.veterinarianLicense:
        return 25;
      case SubscriptionTier.pharmacyLicense:
        // Firma: stvarni limit određuje ScanLimitService + PaymentService (regija).
        return 100;
    }
  }

  static int limitForRole(UserRole role, ScanMarket market) {
    switch (role) {
      case UserRole.hobbyFarmer:
        return hobbyLimit(market);
      case UserRole.professionalFarmer:
        return professionalLimit(market);
      case UserRole.veterinarian:
        return limitForTier(SubscriptionTier.veterinarianLicense, market);
      case UserRole.pharmacy:
        return limitForTier(SubscriptionTier.pharmacyLicense, market);
      case UserRole.buyer:
        return buyerLimit(market);
      default:
        return buyerLimit(market);
    }
  }
}
