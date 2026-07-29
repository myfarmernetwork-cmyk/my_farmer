import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../providers/locale_settings_provider.dart';
import '../services/payment_service.dart';

/// Tekst s brojem skenova firme prema GPS / regiji naplate (ne fiksni „100“).
String companyRoleInfoForContext(
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

  return PaymentService.applyCompanyScanCountTemplate(
    'role_company_info'.tr(),
    languageCode: context.locale.languageCode,
    countryCode: country,
    currencyRegion: region,
  );
}

String companyPharmacyFeaturesForContext(
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

  return PaymentService.applyCompanyScanCountTemplate(
    'paywall_pharmacy_features'.tr(),
    languageCode: context.locale.languageCode,
    countryCode: country,
    currencyRegion: region,
  );
}
