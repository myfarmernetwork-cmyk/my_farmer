import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/subscription_limits.dart';
import '../models/premium_access.dart';
import '../providers/locale_settings_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/payment_service.dart';
import 'farmer_help_widgets.dart';
import 'premium_gate.dart' show showSubscriptionPendingNotice;
import 'premium_gate.dart' show PremiumGate;

String? _billingCountry(WidgetRef ref) {
  final user = ref.read(userDocProvider).valueOrNull;
  return PaymentService.resolveBillingCountryForPricing(
    paymentCountryCode: user?.paymentCountryCode ??
        PaymentService.cachedPaymentCountryCode,
  );
}

String? _vetCurrencyRegion(BuildContext context, WidgetRef ref) {
  final user = ref.read(userDocProvider).valueOrNull;
  final billingCountry = _billingCountry(ref);
  final region = resolveCurrencyRegionForUser(
    locale: context.locale,
    storedRegion: user?.currencyRegion,
    deviceCountryCode: billingCountry ??
        PaymentService.cachedGpsVerifiedCountryCode ??
        PaymentService.cachedIpCountryCode ??
        PaymentService.cachedDeviceCountryCode,
    paymentCountryCode: user?.paymentCountryCode,
    role: user?.role,
  );
  return PaymentService.vetCurrencyRegion(
    languageCode: context.locale.languageCode,
    currencyRegion: region,
    countryCode: billingCountry,
  );
}

String? _companyCurrencyRegion(BuildContext context, WidgetRef ref) {
  final user = ref.read(userDocProvider).valueOrNull;
  final stored = ref.watch(currencyRegionProvider) ?? user?.currencyRegion;
  final billingCountry = _billingCountry(ref);
  return resolveCurrencyRegionForUser(
    locale: context.locale,
    storedRegion: stored,
    deviceCountryCode: billingCountry ??
        PaymentService.cachedGpsVerifiedCountryCode ??
        PaymentService.cachedIpCountryCode ??
        PaymentService.cachedDeviceCountryCode,
    paymentCountryCode: user?.paymentCountryCode,
    role: user?.role,
  );
}

CompanyQuoteRequest companyQuoteRequest(BuildContext context, WidgetRef ref) {
  return CompanyQuoteRequest(
    languageCode: context.locale.languageCode,
    currencyRegion: _companyCurrencyRegion(context, ref),
  );
}

/// Regionalna cijena poslovne pretplate — GPS/regija, ne statički JSON.
String companyPremiumPriceLine(BuildContext context, WidgetRef ref) {
  return PaymentService.companyPriceLine(
    languageCode: context.locale.languageCode,
    currencyRegion: _companyCurrencyRegion(context, ref),
  );
}

String companyPremiumActivateButtonLabel(
  BuildContext context,
  WidgetRef ref,
) {
  return PaymentService.companySubscribeButtonLabel(
    languageCode: context.locale.languageCode,
    currencyRegion: _companyCurrencyRegion(context, ref),
  );
}

/// Ključevi pogodnosti poslovne pretplate tvrtke (19,99 €/mj).
const kCompanyPremiumBenefitKeys = <String>[
  'paywall_pharmacy_benefit_shop',
  'paywall_pharmacy_benefit_boost',
  'paywall_pharmacy_benefit_scanner',
  'paywall_pharmacy_benefit_ai',
  'paywall_pharmacy_benefit_badge',
];

/// Minimalističke ikone za poslovne pogodnosti tvrtke.
const kCompanyPremiumBenefitIcons = <IconData>[
  Icons.storefront,
  Icons.trending_up,
  Icons.analytics_outlined,
  Icons.auto_awesome,
  Icons.verified,
];

/// Ključevi pogodnosti Premium Veterinar (9,99 €/mj) — bez narudžbi i poruka.
const kVetPremiumBenefitKeys = <String>[
  'paywall_vet_benefit_records',
  'paywall_vet_benefit_pets',
  'paywall_vet_benefit_scanner',
  'paywall_vet_benefit_pharmacy',
  'paywall_vet_benefit_radar',
];

/// Minimalističke ikone za profesionalni prikaz pogodnosti veterinara.
const kVetPremiumBenefitIcons = <IconData>[
  Icons.medical_services,
  Icons.pets,
  Icons.analytics_outlined,
  Icons.local_pharmacy,
  Icons.radar,
];

/// Lista poslovnih pogodnosti za ulogu Tvrtka / Firma.
class CompanyPremiumBenefitsList extends ConsumerWidget {
  const CompanyPremiumBenefitsList({
    super.key,
    this.textStyle,
    this.itemSpacing = 12,
    this.iconColor,
  });

  final TextStyle? textStyle;
  final double itemSpacing;
  final Color? iconColor;

  Widget _benefitRow({
    required IconData icon,
    required String label,
    required TextStyle style,
    required Color iconTint,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: iconTint),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: style,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = textStyle ??
        TextStyle(
          fontSize: 15,
          height: 1.4,
          color: Colors.grey[800],
          fontWeight: FontWeight.w500,
        );
    final iconTint = iconColor ?? Colors.grey[700]!;
    final currencyRegion = _companyCurrencyRegion(context, ref);

    return Column(
      key: ValueKey('company_premium_benefits_${context.locale}_$currencyRegion'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < kCompanyPremiumBenefitKeys.length; i++) ...[
          if (i > 0) SizedBox(height: itemSpacing),
          _benefitRow(
            icon: kCompanyPremiumBenefitIcons[i],
            label: kCompanyPremiumBenefitKeys[i] ==
                    'paywall_pharmacy_benefit_scanner'
                ? PaymentService.companyScannerBenefitLine(
                    languageCode: context.locale.languageCode,
                    countryCode: _billingCountry(ref),
                    currencyRegion: currencyRegion,
                  )
                : farmerGuideTr(context, kCompanyPremiumBenefitKeys[i]),
            style: style,
            iconTint: iconTint,
          ),
        ],
      ],
    );
  }
}

/// Ključevi pogodnosti Hobi Farmer Premium (3,99 €/mj).
const kHobbyPremiumBenefitKeys = <String>[
  'paywall_hobby_benefit_scanner',
  'paywall_hobby_benefit_satellite',
  'paywall_hobby_benefit_nirs',
  'paywall_hobby_benefit_parcels',
  'paywall_hobby_benefit_animals',
  'paywall_hobby_benefit_products',
  'paywall_hobby_benefit_reservation',
];

const kHobbyPremiumBenefitIcons = <IconData>[
  Icons.biotech,
  Icons.satellite_alt,
  Icons.grass_outlined,
  Icons.landscape_outlined,
  Icons.pets,
  Icons.storefront_outlined,
  Icons.event_available_outlined,
];

/// Lista pogodnosti za ulogu Hobi Farmer.
class HobbyPremiumBenefitsList extends ConsumerWidget {
  const HobbyPremiumBenefitsList({
    super.key,
    this.textStyle,
    this.itemSpacing = 12,
    this.iconColor,
  });

  final TextStyle? textStyle;
  final double itemSpacing;
  final Color? iconColor;

  String _benefitLabel(
    BuildContext context,
    WidgetRef ref,
    String key, {
    required String? currencyRegion,
    required String? billingCountry,
  }) {
    if (key == 'paywall_hobby_benefit_scanner') {
      return PaymentService.hobbyScannerBenefitLine(
        languageCode: context.locale.languageCode,
        countryCode: billingCountry,
        currencyRegion: currencyRegion,
      );
    }
    if (key == 'paywall_hobby_benefit_nirs') {
      return farmerGuideTr(context, key).replaceAll(
        '{count}',
        '${SubscriptionLimits.hobbyPremiumNirsMonthlyLoads}',
      );
    }
    if (key == 'paywall_hobby_benefit_parcels') {
      return farmerGuideTr(context, key).replaceAll(
        '{count}',
        '${SubscriptionLimits.hobbyPremiumMaxParcels}',
      );
    }
    if (key == 'paywall_hobby_benefit_animals') {
      return farmerGuideTr(context, key).replaceAll(
        '{count}',
        '${SubscriptionLimits.hobbyPremiumMaxAnimals}',
      );
    }
    if (key == 'paywall_hobby_benefit_products') {
      return farmerGuideTr(context, key).replaceAll(
        '{count}',
        '${SubscriptionLimits.hobbyMaxActiveProducts}',
      );
    }
    return farmerGuideTr(context, key);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = textStyle ??
        TextStyle(
          fontSize: 15,
          height: 1.4,
          color: Colors.grey[800],
          fontWeight: FontWeight.w500,
        );
    final iconTint = iconColor ?? Colors.grey[700]!;
    final billingCountry = _billingCountry(ref);
    final currencyRegion = resolveCurrencyRegionForUser(
      locale: context.locale,
      storedRegion: ref.read(userDocProvider).valueOrNull?.currencyRegion,
      deviceCountryCode: billingCountry ??
          PaymentService.cachedGpsVerifiedCountryCode ??
          PaymentService.cachedIpCountryCode ??
          PaymentService.cachedDeviceCountryCode,
      paymentCountryCode: ref.read(userDocProvider).valueOrNull?.paymentCountryCode,
      role: ref.read(userDocProvider).valueOrNull?.role,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < kHobbyPremiumBenefitKeys.length; i++) ...[
          if (i > 0) SizedBox(height: itemSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                kHobbyPremiumBenefitIcons[i],
                size: 22,
                color: iconTint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _benefitLabel(
                    context,
                    ref,
                    kHobbyPremiumBenefitKeys[i],
                    currencyRegion: currencyRegion,
                    billingCountry: billingCountry,
                  ),
                  style: style,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Ključevi pogodnosti Pro Farmer Premium (9,99 €/mj).
const kProPremiumBenefitKeys = <String>[
  'paywall_pro_benefit_scanner',
  'paywall_pro_benefit_satellite',
  'paywall_pro_benefit_nirs',
  'paywall_pro_benefit_parcels',
  'paywall_pro_benefit_animals',
  'paywall_pro_benefit_agro_alarms',
  'paywall_pro_benefit_selling',
];

const kProPremiumBenefitIcons = <IconData>[
  Icons.biotech,
  Icons.satellite_alt,
  Icons.grass_outlined,
  Icons.landscape_outlined,
  Icons.pets,
  Icons.notifications_active_outlined,
  Icons.storefront_outlined,
];

/// Lista pogodnosti za ulogu Profesionalni Farmer.
class ProPremiumBenefitsList extends ConsumerWidget {
  const ProPremiumBenefitsList({
    super.key,
    this.textStyle,
    this.itemSpacing = 12,
    this.iconColor,
  });

  final TextStyle? textStyle;
  final double itemSpacing;
  final Color? iconColor;

  String _benefitLabel(
    BuildContext context,
    WidgetRef ref,
    String key, {
    required String? currencyRegion,
    required String? billingCountry,
  }) {
    if (key == 'paywall_pro_benefit_scanner') {
      return PaymentService.proScannerBenefitLine(
        languageCode: context.locale.languageCode,
        countryCode: billingCountry,
        currencyRegion: currencyRegion,
      );
    }
    if (key == 'paywall_pro_benefit_nirs') {
      return farmerGuideTr(context, key).replaceAll(
        '{count}',
        '${SubscriptionLimits.proPremiumNirsMonthlyLoads}',
      );
    }
    if (key == 'paywall_pro_benefit_parcels') {
      return farmerGuideTr(context, key).replaceAll(
        '{count}',
        '${SubscriptionLimits.proPremiumMaxParcels}',
      );
    }
    if (key == 'paywall_pro_benefit_animals') {
      return farmerGuideTr(context, key).replaceAll(
        '{count}',
        '${SubscriptionLimits.proPremiumMaxAnimals}',
      );
    }
    return farmerGuideTr(context, key);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = textStyle ??
        TextStyle(
          fontSize: 15,
          height: 1.4,
          color: Colors.grey[800],
          fontWeight: FontWeight.w500,
        );
    final iconTint = iconColor ?? Colors.grey[700]!;
    final billingCountry = _billingCountry(ref);
    final currencyRegion = resolveCurrencyRegionForUser(
      locale: context.locale,
      storedRegion: ref.read(userDocProvider).valueOrNull?.currencyRegion,
      deviceCountryCode: billingCountry ??
          PaymentService.cachedGpsVerifiedCountryCode ??
          PaymentService.cachedIpCountryCode ??
          PaymentService.cachedDeviceCountryCode,
      paymentCountryCode: ref.read(userDocProvider).valueOrNull?.paymentCountryCode,
      role: ref.read(userDocProvider).valueOrNull?.role,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < kProPremiumBenefitKeys.length; i++) ...[
          if (i > 0) SizedBox(height: itemSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                kProPremiumBenefitIcons[i],
                size: 22,
                color: iconTint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _benefitLabel(
                    context,
                    ref,
                    kProPremiumBenefitKeys[i],
                    currencyRegion: currencyRegion,
                    billingCountry: billingCountry,
                  ),
                  style: style,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Lista 5 točnih tehnoloških pogodnosti za ulogu Veterinar.
class VetPremiumBenefitsList extends ConsumerWidget {
  const VetPremiumBenefitsList({
    super.key,
    this.textStyle,
    this.itemSpacing = 12,
    this.iconColor,
  });

  final TextStyle? textStyle;
  final double itemSpacing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = textStyle ??
        TextStyle(
          fontSize: 15,
          height: 1.4,
          color: Colors.grey[800],
          fontWeight: FontWeight.w500,
        );
    final iconTint = iconColor ?? Colors.grey[700]!;
    final currencyRegion = _vetCurrencyRegion(context, ref);
    final billingCountry = _billingCountry(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < kVetPremiumBenefitKeys.length; i++) ...[
          if (i > 0) SizedBox(height: itemSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                kVetPremiumBenefitIcons[i],
                size: 22,
                color: iconTint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  kVetPremiumBenefitKeys[i] == 'paywall_vet_benefit_scanner'
                      ? PaymentService.vetScannerBenefitLine(
                          languageCode: context.locale.languageCode,
                          currencyRegion: currencyRegion,
                          countryCode: billingCountry,
                        )
                      : farmerGuideTr(context, kVetPremiumBenefitKeys[i]),
                  style: style,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Jedinstveni Premium Gate za veterinara — isključivo 9,99 €/mj.
class PremiumGateDialog extends ConsumerWidget {
  const PremiumGateDialog({
    super.key,
    required this.onUnlocked,
  });

  final VoidCallback onUnlocked;

  /// Jedina platna brava za ulogu Veterinar — 9,99 €/mj.
  static Future<void> showForVeterinarian(
    BuildContext context,
    WidgetRef ref, {
    required VoidCallback onUnlocked,
  }) async {
    if (ref.read(grantsFullPremiumProvider)) {
      onUnlocked();
      return;
    }

    if (ref.read(premiumAccessProvider).canUse(PremiumFeature.digitalMedicalIntake)) {
      onUnlocked();
      return;
    }

    final user = ref.read(userDocProvider).valueOrNull;
    final storePremium = ref.read(isPremiumProvider).value ?? false;
    if (userAlreadySubscribed(user: user, storePremium: storePremium)) {
      if (context.mounted) {
        if (user?.isPremiumPending == true) {
          showSubscriptionPendingNotice(context);
        }
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => PremiumGateDialog(onUnlocked: onUnlocked),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(userDocProvider).valueOrNull;
    final billingCountry = _billingCountry(ref);
    final vetRegion = _vetCurrencyRegion(context, ref);
    final paymentCountry = user?.paymentCountryCode ??
        PaymentService.cachedPaymentCountryCode;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.medical_services, color: Colors.grey[700], size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'paywall_vet_title'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const VetPremiumBenefitsList(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              PaymentService.vetPriceLine(
                languageCode: context.locale.languageCode,
                currencyRegion: vetRegion,
                countryCode: billingCountry,
                paymentCountryCode: paymentCountry,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cart_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await PremiumGate.run(
              context,
              ref,
              feature: PremiumFeature.digitalMedicalIntake,
              onUnlocked: onUnlocked,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[800],
            foregroundColor: Colors.white,
          ),
          child: Text(
            PaymentService.vetSubscribeButtonLabel(
              languageCode: context.locale.languageCode,
              currencyRegion: vetRegion,
              countryCode: billingCountry,
              paymentCountryCode: paymentCountry,
            ),
          ),
        ),
      ],
    );
  }
}

/// Jedinstveni Premium Gate za tvrtku — isključivo 19,99 €/mj.
class CompanyPremiumGateDialog extends ConsumerWidget {
  const CompanyPremiumGateDialog({
    super.key,
    required this.feature,
    required this.onUnlocked,
  });

  final PremiumFeature feature;
  final VoidCallback onUnlocked;

  /// Jedina platna brava za ulogu Tvrtka — 19,99 €/mj.
  static Future<void> showForCompany(
    BuildContext context,
    WidgetRef ref, {
    PremiumFeature feature = PremiumFeature.marketplaceBoost,
    required VoidCallback onUnlocked,
  }) async {
    if (ref.read(grantsFullPremiumProvider)) {
      onUnlocked();
      return;
    }

    if (ref.read(premiumAccessProvider).canUse(feature) ||
        ref.read(premiumAccessProvider).canUse(PremiumFeature.marketplaceBoost)) {
      onUnlocked();
      return;
    }

    final user = ref.read(userDocProvider).valueOrNull;
    final storePremium = ref.read(isPremiumProvider).value ?? false;
    if (userAlreadySubscribed(user: user, storePremium: storePremium)) {
      if (context.mounted) {
        if (user?.isPremiumPending == true) {
          showSubscriptionPendingNotice(context);
        }
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => CompanyPremiumGateDialog(
        feature: feature,
        onUnlocked: onUnlocked,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteRequest = companyQuoteRequest(context, ref);

    return AlertDialog(
      key: ValueKey('company_premium_gate_${context.locale}_${quoteRequest.currencyRegion}'),
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.storefront, color: Colors.grey[700], size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'paywall_pharmacy_title'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CompanyPremiumBenefitsList(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              companyPremiumPriceLine(context, ref),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cart_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await PremiumGate.run(
              context,
              ref,
              feature: feature,
              onUnlocked: onUnlocked,
              skipCompanyDialog: true,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[800],
            foregroundColor: Colors.white,
          ),
          child: Text(
            companyPremiumActivateButtonLabel(context, ref),
          ),
        ),
      ],
    );
  }
}
