import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/subscription_tier.dart';
import '../services/currency_service.dart';
import '../services/payment_service.dart';

/// RevenueCat / Google Play konfiguracija.
///
/// Release build (Play Store):
/// ```powershell
/// flutter build appbundle --release `
///   --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx `
///   --dart-define=REVENUECAT_SIMULATION=false
/// ```
///
/// Play Console product ID-jevi (moraju se poklapati 1:1 s RevenueCat):
/// - [premiumHobbyMonthly]
/// - [premiumProMonthly]
/// - [licenseVetMonthly]
/// - [licensePharmacyMonthly]
/// - [scanTopUpPack]
class RevenueCatConfig {
  RevenueCatConfig._();

  static const String androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: '',
  );

  static const String iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: '',
  );

  /// Entitlement u RevenueCat dashboardu (zajednički za sve pakete).
  static const String entitlementId = 'premium';

  /// Produkcija: mora ostati `false` (default). Dev: `--dart-define=REVENUECAT_SIMULATION=true`
  static const bool simulationMode = bool.fromEnvironment(
    'REVENUECAT_SIMULATION',
    defaultValue: false,
  );

  /// Stvarna Play Store naplata (ne simulacija).
  static bool get isLivePlayBilling => !simulationMode;

  /// Release AAB mora imati Android ključ i isključenu simulaciju.
  static void assertProductionBillingReady() {
    if (!kReleaseMode) return;

    if (simulationMode) {
      throw StateError(
        'REVENUECAT_SIMULATION mora biti false u release buildu.',
      );
    }
    if (androidApiKey.isEmpty) {
      throw StateError(
        'REVENUECAT_ANDROID_KEY je obavezan u release buildu.',
      );
    }
  }

  // ── Google Play Product ID-ovi (Play Console + RevenueCat) ──────────────

  static const String premiumBuyerMonthly = 'premium_buyer_monthly';
  static const String premiumHobbyMonthly = 'premium_hobby_monthly';
  static const String premiumProMonthly = 'premium_pro_monthly';
  static const String licenseVetMonthly = 'license_vet_monthly';
  static const String licensePharmacyMonthly = 'license_pharmacy_monthly';
  static const String scanTopUpPack = 'scan_topup_pack';

  /// Svi ID-jevi koje treba kreirati u Play Console i mapirati u RevenueCat.
  static const Map<String, String> playStoreProductLabels = {
    premiumHobbyMonthly: 'Hobi Farmer Premium (mjesečno)',
    premiumProMonthly: 'Pro Farmer Premium (mjesečno)',
    licenseVetMonthly: 'Veterinar licenca (mjesečno)',
    licensePharmacyMonthly: 'Apoteka / firma licenca (mjesečno)',
    scanTopUpPack: 'Dokup AI skenova (consumable)',
    premiumBuyerMonthly: 'Kupac Premium (mjesečno)',
  };

  /// Kanonske mjesečne cijene u centima (EUR) — izvor istine za simulaciju i fallback UI.
  static const Map<String, int> monthlyPriceCentsEurByProductId = {
    premiumBuyerMonthly: 199,
    premiumHobbyMonthly: 399,
    premiumProMonthly: 999,
    licenseVetMonthly: 999,
    licensePharmacyMonthly: 1999,
  };

  static int? monthlyPriceCentsForProductId(String productId) =>
      monthlyPriceCentsEurByProductId[productId];

  static double? monthlyPriceEurForProductId(String productId) {
    final cents = monthlyPriceCentsForProductId(productId);
    if (cents == null) return null;
    return cents / 100.0;
  }

  /// Prikaz cijene u simulacijskom modu (kad Play Store nije aktivan).
  static String? simulationPriceLabelForProductId(
    String productId, {
    required String languageCode,
    String? currencyRegion,
    String? countryCode,
    String? paymentCountryCode,
  }) {
    if (productId == licenseVetMonthly) {
      return PaymentService.vetPriceLine(
        languageCode: languageCode,
        currencyRegion: PaymentService.vetCurrencyRegion(
          languageCode: languageCode,
          currencyRegion: currencyRegion,
          countryCode: countryCode,
        ),
        countryCode: countryCode,
        paymentCountryCode: paymentCountryCode,
      );
    }

    final regional = PaymentService.subscriptionPriceLineForProduct(
      productId: productId,
      languageCode: languageCode,
      countryCode: countryCode,
      currencyRegion: currencyRegion,
      paymentCountryCode: paymentCountryCode,
    );
    if (regional != null) return regional;

    final eur = monthlyPriceEurForProductId(productId);
    if (eur == null) return null;
    final lang = languageCode == 'bs' ? 'hr' : languageCode;

    if (lang == 'zh') {
      final cny = CurrencyService().convertAmount(
        eur,
        CurrencyService.eur,
        CurrencyService.cny,
      );
      final s = _formatEuroAmount(cny, decimalSeparator: '.');
      return '¥$s / 每月';
    }
    if (lang == 'de') {
      final s = _formatEuroAmount(eur, decimalSeparator: ',');
      return '$s € / Monat';
    }
    if (lang == 'en') {
      final s = _formatEuroAmount(eur, decimalSeparator: '.');
      return '€$s per month';
    }
    if (lang == 'hr') {
      final s = _formatEuroAmount(eur, decimalSeparator: ',');
      return '$s € mjesečno';
    }
    final s = _formatEuroAmount(eur, decimalSeparator: ',');
    return '$s KM / $s € mjesečno';
  }

  static String _formatEuroAmount(double amount, {required String decimalSeparator}) {
    final parts = amount.toStringAsFixed(2).split('.');
    return '${parts[0]}$decimalSeparator${parts[1]}';
  }

  static const List<String> allProductIds = [
    premiumBuyerMonthly,
    premiumHobbyMonthly,
    premiumProMonthly,
    licenseVetMonthly,
    licensePharmacyMonthly,
    scanTopUpPack,
  ];

  static const Map<String, SubscriptionTier> tierByProductId = {
    premiumBuyerMonthly: SubscriptionTier.buyerPremium,
    premiumHobbyMonthly: SubscriptionTier.hobbyFarmerPremium,
    premiumProMonthly: SubscriptionTier.professionalFarmerPremium,
    licenseVetMonthly: SubscriptionTier.veterinarianLicense,
    licensePharmacyMonthly: SubscriptionTier.pharmacyLicense,
  };

  static SubscriptionTier? tierForProductId(String productId) =>
      tierByProductId[productId];

  /// Preporučeni paket za ulogu (prvi u paywall listi).
  static String recommendedProductIdForRole(UserRole role) {
    return productIdsForRole(role).first;
  }

  /// Jedini paket prikazan na paywallu za danu ulogu.
  static List<String> productIdsForRole(UserRole role) {
    switch (role) {
      case UserRole.hobbyFarmer:
        return [premiumHobbyMonthly];
      case UserRole.professionalFarmer:
        return [premiumProMonthly];
      case UserRole.veterinarian:
        return [licenseVetMonthly];
      case UserRole.pharmacy:
        return [licensePharmacyMonthly];
      default:
        return [premiumBuyerMonthly];
    }
  }

  static String? titleKeyForProductId(String productId) {
    switch (productId) {
      case premiumBuyerMonthly:
        return 'paywall_buyer_title';
      case premiumHobbyMonthly:
        return 'paywall_hobby_title';
      case premiumProMonthly:
        return 'paywall_pro_title';
      case licenseVetMonthly:
        return 'paywall_vet_title';
      case licensePharmacyMonthly:
        return 'paywall_pharmacy_title';
      default:
        return null;
    }
  }

  static String? priceKeyForProductId(String productId) {
    switch (productId) {
      case premiumBuyerMonthly:
        return 'paywall_buyer_price';
      case premiumHobbyMonthly:
        return 'paywall_hobby_price';
      case premiumProMonthly:
        return 'paywall_pro_price';
      case licenseVetMonthly:
        return 'paywall_vet_price';
      case licensePharmacyMonthly:
        return 'paywall_pharmacy_price';
      default:
        return null;
    }
  }

  static String? featuresKeyForProductId(String productId) {
    switch (productId) {
      case premiumBuyerMonthly:
        return 'paywall_buyer_features';
      case premiumHobbyMonthly:
        return 'paywall_hobby_features';
      case premiumProMonthly:
        return 'paywall_pro_features';
      case licenseVetMonthly:
        return 'paywall_vet_features';
      case licensePharmacyMonthly:
        return 'paywall_pharmacy_features';
      default:
        return null;
    }
  }

  static bool get isConfigured => androidApiKey.isNotEmpty || iosApiKey.isNotEmpty;
}
