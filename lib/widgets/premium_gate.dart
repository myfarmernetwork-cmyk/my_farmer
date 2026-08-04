import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/beta_config.dart';
import '../models/premium_access.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_settings_provider.dart';
import '../models/app_user.dart';
import '../screens/paywall_screen.dart';
import '../services/payment_service.dart';
import 'farmer_help_widgets.dart';
import 'premium_gate_dialog.dart'
    show
        CompanyPremiumBenefitsList,
        CompanyPremiumGateDialog,
        HobbyPremiumBenefitsList,
        VetPremiumBenefitsList;

void showSubscriptionPendingNotice(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(farmerGuideTr(context, 'premium_pending_banner')),
      duration: const Duration(seconds: 5),
    ),
  );
}

/// Vrati ključeve za Premium Gate ovisno o značajci.
class PremiumGateKeys {
  PremiumGateKeys._();

  static String titleKey(PremiumFeature feature) {
    switch (feature) {
      case PremiumFeature.upcomingReservation:
        return 'premium_upcoming_title';
      case PremiumFeature.landMeasurement:
        return 'land_premium_title';
      case PremiumFeature.animalRecords:
        return 'paywall_buyer_title';
      case PremiumFeature.vetRadarListing:
        return 'paywall_vet_title';
      case PremiumFeature.marketplaceBoost:
      case PremiumFeature.sponsoredRecommendations:
        return 'paywall_pharmacy_title';
      case PremiumFeature.digitalMedicalIntake:
        return 'paywall_vet_title';
      default:
        return 'paywall_title';
    }
  }

  static String descriptionKey(PremiumFeature feature) {
    switch (feature) {
      case PremiumFeature.upcomingReservation:
        return 'premium_upcoming_desc';
      case PremiumFeature.landMeasurement:
        return 'land_premium_desc';
      case PremiumFeature.animalRecords:
        return 'paywall_buyer_features';
      case PremiumFeature.vetRadarListing:
      case PremiumFeature.digitalMedicalIntake:
        return 'paywall_vet_features';
      case PremiumFeature.marketplaceBoost:
      case PremiumFeature.sponsoredRecommendations:
        return 'paywall_pharmacy_features';
      default:
        return 'paywall_subtitle';
    }
  }
}

class PremiumGate {
  static Future<void> run(
    BuildContext context,
    WidgetRef ref, {
    required PremiumFeature feature,
    required VoidCallback onUnlocked,
    bool skipCompanyDialog = false,
  }) async {
    if (ref.read(grantsFullPremiumProvider)) {
      onUnlocked();
      return;
    }

    final user = ref.read(userDocProvider).valueOrNull ??
        ref.read(authStateProvider).valueOrNull;

    if (ref.read(premiumAccessProvider).canUse(feature)) {
      onUnlocked();
      return;
    }

    final storePremium = ref.read(isPremiumProvider).value ?? false;
    if (userAlreadySubscribed(user: user, storePremium: storePremium)) {
      if (!context.mounted) return;
      if (user?.isPremiumPending == true) {
        showSubscriptionPendingNotice(context);
      }
      if (ref.read(premiumAccessProvider).canUse(feature)) {
        onUnlocked();
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('premium_activation_syncing'.tr()),
          duration: const Duration(seconds: 4),
        ),
      );
      await ref.read(subscriptionServiceProvider).refreshPremiumStatus();
      if (!context.mounted) return;
      if (ref.read(premiumAccessProvider).canUse(feature)) {
        onUnlocked();
      }
      return;
    }

    if (!skipCompanyDialog && user?.role == UserRole.pharmacy) {
      await CompanyPremiumGateDialog.showForCompany(
        context,
        ref,
        feature: feature,
        onUnlocked: onUnlocked,
      );
      return;
    }

    if (!PaymentService.hasGpsVerifiedLocation) {
      final device = await PaymentService.resolveDeviceCountryForPricing();
      if (device == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('location_install_gps_required_pay'.tr())),
        );
        return;
      }
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );

    await ref.read(subscriptionServiceProvider).refreshPremiumStatus();

    if (!context.mounted) return;
    if (ref.read(premiumAccessProvider).canUse(feature)) {
      onUnlocked();
    }
  }
}

class PremiumFeatureScreen extends ConsumerWidget {
  final PremiumFeature feature;
  final Widget child;
  final String titleKey;
  final String descriptionKey;
  final IconData icon;

  const PremiumFeatureScreen({
    super.key,
    required this.feature,
    required this.child,
    required this.titleKey,
    required this.descriptionKey,
    this.icon = Icons.lock_outline,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(grantsFullPremiumProvider)) {
      return child;
    }

    final access = ref.watch(premiumAccessProvider);

    if (access.canUse(feature)) {
      return child;
    }

    return PremiumLockedView(
      feature: feature,
      titleKey: titleKey,
      descriptionKey: descriptionKey,
      icon: icon,
    );
  }
}

class PremiumLockedView extends ConsumerWidget {
  final PremiumFeature feature;
  final String titleKey;
  final String descriptionKey;
  final String buttonKey;
  final IconData icon;

  const PremiumLockedView({
    super.key,
    required this.feature,
    required this.titleKey,
    required this.descriptionKey,
    this.buttonKey = 'paywall_start_premium',
    required this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(premiumAccessProvider);
    final user = ref.watch(userDocProvider).valueOrNull ??
        ref.watch(authStateProvider).valueOrNull;
    final role = access.role;
    final isVet = role == UserRole.veterinarian;
    final isCompany = role == UserRole.pharmacy;
    final isHobby = role == UserRole.hobbyFarmer;
    final isVetAiScanner = isVet && feature == PremiumFeature.aiScanner;
    final isCompanyAiScanner = isCompany && feature == PremiumFeature.aiScanner;
    final billingCountry = PaymentService.resolveBillingCountryForPricing(
      paymentCountryCode: user?.paymentCountryCode ??
          PaymentService.cachedPaymentCountryCode,
    );
    final deviceCountryForRegion = billingCountry ??
        PaymentService.cachedGpsVerifiedCountryCode ??
        PaymentService.cachedIpCountryCode ??
        PaymentService.cachedDeviceCountryCode;
    final companyCurrencyRegion = isCompany
        ? resolveCurrencyRegionForUser(
            locale: context.locale,
            storedRegion: ref.watch(currencyRegionProvider) ??
                user?.currencyRegion,
            deviceCountryCode: deviceCountryForRegion,
            paymentCountryCode: user?.paymentCountryCode,
            role: role,
          )
        : null;
    final vetCurrencyRegion = isVet
        ? PaymentService.vetCurrencyRegion(
            languageCode: context.locale.languageCode,
            currencyRegion: resolveCurrencyRegionForUser(
              locale: context.locale,
              storedRegion: user?.currencyRegion,
              deviceCountryCode: deviceCountryForRegion,
              paymentCountryCode: user?.paymentCountryCode,
              role: role,
            ),
            countryCode: billingCountry,
          )
        : null;
    final hobbyCurrencyRegion = isHobby
        ? resolveCurrencyRegionForUser(
            locale: context.locale,
            storedRegion: ref.watch(currencyRegionProvider) ??
                user?.currencyRegion,
            deviceCountryCode: deviceCountryForRegion,
            paymentCountryCode: user?.paymentCountryCode,
            role: role,
          )
        : null;

    String lockedTitle() {
      if (isVetAiScanner || isCompanyAiScanner) {
        return 'nav_ai_scanner'.tr();
      }
      if (isVet) return 'paywall_vet_title'.tr();
      if (isCompany) return 'paywall_pharmacy_title'.tr();
      if (isHobby) return 'paywall_hobby_title'.tr();
      return titleKey.tr();
    }

    return Scaffold(
      key: ValueKey(
        'premium_locked_${feature.name}_${context.locale}_$companyCurrencyRegion',
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.green[50],
                            child: Icon(icon, size: 40, color: Colors.green[800]),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  lockedTitle(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.workspace_premium,
                                  color: Colors.amber[700], size: 24),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isVet)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    farmerGuideTr(
                                      context,
                                      'paywall_vet_features_intro',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const VetPremiumBenefitsList(
                                    itemSpacing: 10,
                                  ),
                                ],
                              ),
                            )
                            else if (isCompany)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    farmerGuideTr(
                                      context,
                                      'paywall_pharmacy_features_intro',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const CompanyPremiumBenefitsList(
                                    itemSpacing: 10,
                                  ),
                                ],
                              ),
                            )
                          else if (isHobby)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    farmerGuideTr(
                                      context,
                                      'paywall_hobby_features_intro',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const HobbyPremiumBenefitsList(
                                    itemSpacing: 10,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      PaymentService.hobbyPriceLine(
                                        languageCode:
                                            context.locale.languageCode,
                                        countryCode: billingCountry,
                                        currencyRegion: hobbyCurrencyRegion,
                                        paymentCountryCode:
                                            user?.paymentCountryCode ??
                                                PaymentService
                                                    .cachedPaymentCountryCode,
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
                            )
                          else
                            Text(
                              descriptionKey.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => PremiumGate.run(
                                context,
                                ref,
                                feature: feature,
                                onUnlocked: () {},
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800],
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isCompany
                                  ? Text(
                                      PaymentService.companySubscribeButtonLabel(
                                        languageCode:
                                            context.locale.languageCode,
                                        currencyRegion: companyCurrencyRegion,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : isVet
                                      ? Text(
                                          PaymentService.vetSubscribeButtonLabel(
                                            languageCode:
                                                context.locale.languageCode,
                                            currencyRegion: vetCurrencyRegion,
                                            countryCode: billingCountry,
                                            paymentCountryCode:
                                                user?.paymentCountryCode ??
                                                    PaymentService
                                                        .cachedPaymentCountryCode,
                                          ),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : isHobby
                                          ? Text(
                                              PaymentService
                                                  .hobbySubscribeButtonLabel(
                                                languageCode: context
                                                    .locale.languageCode,
                                                countryCode: billingCountry,
                                                currencyRegion:
                                                    hobbyCurrencyRegion,
                                                paymentCountryCode: user
                                                        ?.paymentCountryCode ??
                                                    PaymentService
                                                        .cachedPaymentCountryCode,
                                              ),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : Text(
                                          buttonKey.tr(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
