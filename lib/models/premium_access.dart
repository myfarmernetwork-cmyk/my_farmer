import 'dart:ui';

import 'app_user.dart';

import 'scan_market_limits.dart';

import 'subscription_tier.dart';

import '../config/subscription_limits.dart';
import '../providers/locale_settings_provider.dart';
import '../services/payment_service.dart';



enum PremiumFeature {

  orders,

  upcomingReservation,

  chat,

  aiScanner,

  animalRecords,

  services,

  landMeasurement,

  vetRadarListing,

  marketplaceBoost,

  sponsoredRecommendations,

  digitalMedicalIntake,

}



class PremiumAccess {

  final AppUser? user;

  final bool isPremium;

  final bool isAdminBypass;

  /// Zatvoreno testiranje — pun premium bez plaćanja (samo BETA_FREE_PREMIUM build).
  final bool closedTestFreePremium;

  /// Firestore — chat besplatni za sve u testiranju.
  final bool closedTestingFreeChat;

  /// Firestore — AI skener besplatan u testiranju (sve uloge).
  final bool closedTestingFreeAiScanner;

  /// Firestore — kartoteka pacijenata besplatna za veterinare u testiranju.
  final bool closedTestingFreeVetIntake;

  final UserRole effectiveRole;

  final String languageCode;



  const PremiumAccess({

    required this.user,

    required this.isPremium,

    this.isAdminBypass = false,

    this.closedTestFreePremium = false,

    this.closedTestingFreeChat = false,

    this.closedTestingFreeAiScanner = false,

    this.closedTestingFreeVetIntake = false,

    this.effectiveRole = UserRole.buyer,

    this.languageCode = 'hr',

  });



  ScanMarket get market => ScanMarketLimits.fromLanguageCode(languageCode);



  UserRole get role => effectiveRole;

  bool get grantsFullPremium => isAdminBypass || closedTestFreePremium;

  SubscriptionTier? get activeTier => user?.approvedTier;

  SubscriptionTier? get effectiveSubscriptionTier => _effectiveTier;

  bool get hasPharmacyLicense => _hasPharmacyLicense;



  bool get _hasIntroScansLeft =>

      (user?.hasFreeScans ?? true) &&

      !(user?.isTrialUsed ?? false) &&

      (user?.introScansUsed ?? 0) < SubscriptionLimits.introAiScansTotal;



  bool get _hasBuyerPremium =>

      _effectiveTier == SubscriptionTier.buyerPremium ||

      _effectiveTier == SubscriptionTier.hobbyFarmerPremium ||

      _effectiveTier == SubscriptionTier.professionalFarmerPremium ||

      _hasHigherThanBuyer;



  bool get _hasHobbyPremium =>

      _effectiveTier == SubscriptionTier.hobbyFarmerPremium ||

      _effectiveTier == SubscriptionTier.professionalFarmerPremium;



  bool get _hasProPremium =>

      _effectiveTier == SubscriptionTier.professionalFarmerPremium;



  bool get _hasHigherThanBuyer => _hasHobbyPremium || _hasProPremium;



  SubscriptionTier? get _effectiveTier {

    if (user == null) return null;

    if (isAdminBypass || closedTestFreePremium) {
      return _previewTierForRole(effectiveRole);
    }

    if (user!.needsAdminVerification) {
      return user!.isPremiumApproved ? user!.approvedTier : null;
    }

    final stored = SubscriptionTierX.fromFirestore(user!.subscriptionTier);
    if (stored != null) return stored;

    final requested = SubscriptionTierX.fromFirestore(user!.requestedPremiumTier);
    if (requested != null && _tierMatchesRole(requested, effectiveRole)) {
      return requested;
    }

    if (user!.premiumActive || isPremium || isInPromoPeriod) {
      return _consumerTierForRole();
    }

    return null;

  }

  bool _tierMatchesRole(SubscriptionTier tier, UserRole role) {
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

  SubscriptionTier? _previewTierForRole(UserRole previewRole) {
    switch (previewRole) {
      case UserRole.buyer:
        return SubscriptionTier.buyerPremium;
      case UserRole.hobbyFarmer:
        return SubscriptionTier.hobbyFarmerPremium;
      case UserRole.professionalFarmer:
        return SubscriptionTier.professionalFarmerPremium;
      case UserRole.veterinarian:
        return SubscriptionTier.veterinarianLicense;
      case UserRole.pharmacy:
        return SubscriptionTier.pharmacyLicense;
      case UserRole.admin:
        return SubscriptionTier.professionalFarmerPremium;
    }
  }



  bool get _hasVetLicense =>

      _effectiveTier == SubscriptionTier.veterinarianLicense;



  bool get _hasPharmacyLicense =>

      _effectiveTier == SubscriptionTier.pharmacyLicense;



  bool get isInPromoPeriod => user?.isInPromotionalPeriod ?? false;



  bool get hasPaidOrPromoAccess {

    if (user == null) return false;

    if (grantsFullPremium) return true;



    if (user!.needsAdminVerification) {

      return user!.isPremiumApproved && user!.subscriptionTier != null;

    }



    if (isPremium) return true;

    if (user!.premiumActive) return true;

    if (user!.subscriptionTier != null &&
        user!.subscriptionTier!.trim().isNotEmpty) {
      return true;
    }

    if (user!.requestedPremiumTier != null &&
        user!.requestedPremiumTier!.trim().isNotEmpty) {
      return true;
    }

    if (isInPromoPeriod) return true;

    return false;

  }



  bool canUse(PremiumFeature feature) {
    if (grantsFullPremium) return true;

    if (user == null) return false;



    switch (feature) {

      case PremiumFeature.orders:

        if (SubscriptionLimits.buyerCanPurchaseWithoutPremium(role)) {

          return true;

        }

        return _hasBuyerPremium || isPremium || user!.isFarmerRole;



      case PremiumFeature.upcomingReservation:

        return canReserveUpcomingInCart;



      case PremiumFeature.chat:

        if (closedTestingFreeChat) return true;

        return _hasBuyerPremium || isPremium || user!.isFarmerRole ||

            user!.needsAdminVerification;



      case PremiumFeature.animalRecords:

        return SubscriptionLimits.maxAnimals(

              role: role,

              tier: _effectiveTier,

              hasPaidPremium: hasPaidOrPromoAccess,

            ) >

            0;



      case PremiumFeature.aiScanner:

        if (closedTestingFreeAiScanner) return true;

        if (_hasIntroScansLeft) return true;

        if (role == UserRole.veterinarian) {
          return (_hasVetLicense && user!.isPremiumApproved) ||
              isInPromoPeriod ||
              isPremium;
        }

        if (role == UserRole.pharmacy) {
          return (_hasPharmacyLicense && user!.isPremiumApproved) ||
              hasPaidOrPromoAccess ||
              isInPromoPeriod ||
              isPremium;
        }

        return _hasBuyerPremium ||

            _hasHobbyPremium ||

            _hasProPremium ||

            isPremium;



      case PremiumFeature.services:

        return user!.canOfferServices;



      case PremiumFeature.landMeasurement:

        return SubscriptionLimits.canAccessLandMeasurement(role);



      case PremiumFeature.vetRadarListing:

        return SubscriptionLimits.vetAppearsInProximityRadar(

          role: role,

          tier: _effectiveTier,

          isPremiumApproved: user!.isPremiumApproved,

        );



      case PremiumFeature.marketplaceBoost:

        return SubscriptionLimits.sellerHasMarketplaceBoost(

          role: role,

          tier: _effectiveTier,

        );



      case PremiumFeature.sponsoredRecommendations:

        return canUse(PremiumFeature.marketplaceBoost);



      case PremiumFeature.digitalMedicalIntake:

        if (closedTestingFreeVetIntake && role == UserRole.veterinarian) {
          return true;
        }

        return role == UserRole.veterinarian &&

            user!.isPremiumApproved &&

            _hasVetLicense;

    }

  }



  bool get canUseNirsMonitoring => grantsFullPremium ||
      SubscriptionLimits.canUseNirsMonitoring(
        role: role,
        tier: _effectiveTier,
        hasPaidPremium: hasPaidOrPromoAccess,
      );



  bool get canReserveUpcomingInCart => grantsFullPremium ||
      SubscriptionLimits.canReserveUpcomingInCart(
        role: role,
        tier: _effectiveTier,
        hasPaidPremium: hasPaidOrPromoAccess,
      );



  int get maxSavedParcels => grantsFullPremium
      ? 999
      : SubscriptionLimits.maxSavedParcels(
          role: role,
          tier: _effectiveTier,
          hasPaidPremium: hasPaidOrPromoAccess,
        );



  int get maxAnimals => grantsFullPremium
      ? 999
      : SubscriptionLimits.maxAnimals(
          role: role,
          tier: _effectiveTier,
          hasPaidPremium: hasPaidOrPromoAccess,
        );

  int get monthlyNirsLimit {
    if (grantsFullPremium) return 999;
    final euCap = SubscriptionLimits.monthlyNirsLoadsForTier(
      role: role,
      tier: _effectiveTier,
      hasPaidPremium: hasPaidOrPromoAccess,
    );
    if (euCap <= 0) return 0;
    final tier = _effectiveTier;
    if (tier != null &&
        user != null &&
        _isConsumerSubscriptionTier(tier) &&
        (role == UserRole.hobbyFarmer || role == UserRole.professionalFarmer)) {
      return _resolveConsumerNirsCap(tier);
    }
    return euCap;
  }

  /// Regionalni NIRS cap za paywall / preview (bez obzira je li pretplata aktivna).
  int get regionalMonthlyNirsCapPreview {
    final tier = _consumerTierForRole();
    if (tier == null) return 0;
    if (user == null) {
      return SubscriptionLimits.monthlyNirsLoadsForTier(
        role: role,
        tier: tier,
        hasPaidPremium: true,
      );
    }
    return _resolveConsumerNirsCap(tier);
  }



  bool get requiresSubscriptionForScanner =>

      !_hasIntroScansLeft && !canUse(PremiumFeature.aiScanner);



  SubscriptionTier? _consumerTierForRole() {
    switch (role) {
      case UserRole.buyer:
        return SubscriptionTier.buyerPremium;
      case UserRole.hobbyFarmer:
        return SubscriptionTier.hobbyFarmerPremium;
      case UserRole.professionalFarmer:
        return SubscriptionTier.professionalFarmerPremium;
      default:
        return null;
    }
  }

  bool _isConsumerSubscriptionTier(SubscriptionTier tier) {
    return tier == SubscriptionTier.buyerPremium ||
        tier == SubscriptionTier.hobbyFarmerPremium ||
        tier == SubscriptionTier.professionalFarmerPremium;
  }

  int _resolveConsumerScanCap(SubscriptionTier tier) {
    final billing = _consumerBillingContext();
    return PaymentService.resolveSubscriptionMonthlyScanCap(
      tier: tier,
      currencyRegion: billing.region,
      languageCode: languageCode,
      countryCode: billing.country,
    );
  }

  int _resolveConsumerNirsCap(SubscriptionTier tier) {
    final billing = _consumerBillingContext();
    return PaymentService.resolveSubscriptionMonthlyNirsCap(
      tier: tier,
      currencyRegion: billing.region,
      languageCode: languageCode,
      countryCode: billing.country,
    );
  }

  ({String? country, String? region}) _consumerBillingContext() {
    final u = user!;
    final billingCountry = PaymentService.resolveBillingCountryForPricing(
      paymentCountryCode: u.paymentCountryCode ??
          PaymentService.cachedPaymentCountryCode,
    );
    final region = resolveCurrencyRegionForUser(
      locale: Locale(languageCode),
      storedRegion: u.currencyRegion,
      deviceCountryCode: billingCountry,
      paymentCountryCode: u.paymentCountryCode ??
          PaymentService.cachedPaymentCountryCode,
      role: u.role,
    );
    return (country: billingCountry, region: region);
  }

  int monthlyScanLimit() {
    if (user == null) return 0;

    if (grantsFullPremium) {
      return 9999;
    }

    if (_hasIntroScansLeft && !hasPaidOrPromoAccess) {
      return SubscriptionLimits.introAiScansTotal -
          (user!.introScansUsed);
    }

    final tier = _effectiveTier;
    if (role == UserRole.veterinarian &&
        (hasPaidOrPromoAccess || isInPromoPeriod || _hasVetLicense)) {
      return PaymentService.resolveVetMonthlyScanCap(
        currencyRegion: user!.currencyRegion,
        languageCode: languageCode,
        countryCode: PaymentService.resolveBillingCountryForPricing(
          paymentCountryCode: user!.paymentCountryCode ??
              PaymentService.cachedPaymentCountryCode,
        ),
      );
    }

    if (tier != null && _isConsumerSubscriptionTier(tier)) {
      return _resolveConsumerScanCap(tier);
    }

    if (isPremium) {
      final roleTier = _consumerTierForRole();
      if (roleTier != null) {
        return _resolveConsumerScanCap(roleTier);
      }
    }

    return 0;
  }
}


