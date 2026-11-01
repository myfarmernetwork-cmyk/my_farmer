import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/subscription_tier.dart';
import '../providers/locale_settings_provider.dart';
import '../services/payment_service.dart';

({String? country, String region}) _billingContextForCopy(
  BuildContext context, {
  String? currencyRegion,
  String? paymentCountryCode,
}) {
  final country = PaymentService.resolveBillingCountryForPricing(
    paymentCountryCode:
        paymentCountryCode ?? PaymentService.cachedPaymentCountryCode,
  );
  final region = currencyRegion ??
      resolveCurrencyRegionForLocale(
        context.locale,
        deviceCountryCode: country ??
            PaymentService.cachedGpsVerifiedCountryCode ??
            PaymentService.cachedDeviceCountryCode,
      );
  return (country: country, region: region);
}

String _subscriptionScanCopyForContext(
  BuildContext context,
  String translationKey, {
  required SubscriptionTier tier,
  String? currencyRegion,
  String? paymentCountryCode,
}) {
  final billing = _billingContextForCopy(
    context,
    currencyRegion: currencyRegion,
    paymentCountryCode: paymentCountryCode,
  );

  return PaymentService.applySubscriptionScanCountTemplate(
    translationKey.tr(),
    tier: tier,
    languageCode: context.locale.languageCode,
    countryCode: billing.country,
    currencyRegion: billing.region,
  );
}

/// Tekst s brojem skenova firme prema GPS / regiji naplate (ne fiksni „100“).
String companyRoleInfoForContext(
  BuildContext context, {
  String? currencyRegion,
  String? paymentCountryCode,
}) {
  final billing = _billingContextForCopy(
    context,
    currencyRegion: currencyRegion,
    paymentCountryCode: paymentCountryCode,
  );

  return PaymentService.applyCompanyScanCountTemplate(
    'role_company_info'.tr(),
    languageCode: context.locale.languageCode,
    countryCode: billing.country,
    currencyRegion: billing.region,
  );
}

String companyPharmacyFeaturesForContext(
  BuildContext context, {
  String? currencyRegion,
  String? paymentCountryCode,
}) {
  final billing = _billingContextForCopy(
    context,
    currencyRegion: currencyRegion,
    paymentCountryCode: paymentCountryCode,
  );

  return PaymentService.applyCompanyScanCountTemplate(
    'paywall_pharmacy_features'.tr(),
    languageCode: context.locale.languageCode,
    countryCode: billing.country,
    currencyRegion: billing.region,
  );
}

String buyerFeaturesForContext(
  BuildContext context, {
  String? currencyRegion,
  String? paymentCountryCode,
}) {
  return _subscriptionScanCopyForContext(
    context,
    'paywall_buyer_features',
    tier: SubscriptionTier.buyerPremium,
    currencyRegion: currencyRegion,
    paymentCountryCode: paymentCountryCode,
  );
}

String hobbyFeaturesForContext(
  BuildContext context, {
  String? currencyRegion,
  String? paymentCountryCode,
}) {
  return _subscriptionScanCopyForContext(
    context,
    'paywall_hobby_features',
    tier: SubscriptionTier.hobbyFarmerPremium,
    currencyRegion: currencyRegion,
    paymentCountryCode: paymentCountryCode,
  );
}

String buyerRoleInfoForContext(
  BuildContext context, {
  String? currencyRegion,
  String? paymentCountryCode,
}) {
  return _subscriptionScanCopyForContext(
    context,
    'role_buyer_info',
    tier: SubscriptionTier.buyerPremium,
    currencyRegion: currencyRegion,
    paymentCountryCode: paymentCountryCode,
  );
}

String hobbyRoleInfoForContext(
  BuildContext context, {
  String? currencyRegion,
  String? paymentCountryCode,
}) {
  return _subscriptionScanCopyForContext(
    context,
    'role_hobby_farmer_info',
    tier: SubscriptionTier.hobbyFarmerPremium,
    currencyRegion: currencyRegion,
    paymentCountryCode: paymentCountryCode,
  );
}
