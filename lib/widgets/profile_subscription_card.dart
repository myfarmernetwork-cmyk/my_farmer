import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/revenuecat_config.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_settings_provider.dart';
import '../providers/subscription_provider.dart';
import '../screens/paywall_screen.dart';
import '../services/payment_service.dart';
import 'farmer_help_widgets.dart';

/// Kartica pretplate na profilu — pretplati se / otkaži pretplatu za sve uloge.
class ProfileSubscriptionCard extends ConsumerWidget {
  const ProfileSubscriptionCard({super.key});

  String _t(BuildContext context, String key) => farmerGuideTr(context, key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(grantsFullPremiumProvider)) {
      return const SizedBox.shrink();
    }

    final user = ref.watch(userDocProvider).valueOrNull ??
        ref.watch(authStateProvider).valueOrNull;
    final role = user?.role ?? UserRole.buyer;
    final storePremium = ref.watch(isPremiumProvider).value ?? false;

    final isSubscribed = userAlreadySubscribed(
      user: user,
      storePremium: storePremium,
    );
    final isPending = user?.isPremiumPending ?? false;
    final inLicensePromo = _inLicensePromo(user, role);
    final awaitingLicenseApproval = _awaitingLicenseApproval(user, role);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    color: Colors.amber.shade800,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(context, 'profile_subscription_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSubscribed
                            ? _planTitle(role)
                            : inLicensePromo
                                ? 'promo_period_active'.tr()
                                : awaitingLicenseApproval
                                    ? 'registration_pending_verification'.tr()
                                    : _t(context, 'profile_subscription_inactive'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSubscribed && !isPending)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      _t(context, 'profile_subscription_active'),
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.hourglass_top_outlined,
                      size: 18,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'premium_pending_banner'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (!isSubscribed && !inLicensePromo && !awaitingLicenseApproval)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openPaywall(context, ref),
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: Text(
                    _subscribeButtonLabel(context, ref, role),
                    textAlign: TextAlign.center,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (isSubscribed)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => _cancelSubscription(context, ref),
                  icon: Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  label: Text(
                    _t(context, 'profile_subscription_cancel'),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isLicenseRole(UserRole role) =>
      role == UserRole.veterinarian || role == UserRole.pharmacy;

  bool _inLicensePromo(AppUser? user, UserRole role) {
    if (!_isLicenseRole(role) || user == null) return false;
    if (user.isPremiumPending) return false;
    return user.isInPromotionalPeriod;
  }

  bool _awaitingLicenseApproval(AppUser? user, UserRole role) {
    if (!_isLicenseRole(role) || user == null) return false;
    return user.needsAdminVerification && !user.isPremiumApproved;
  }

  String _planTitle(UserRole role) {
    switch (role) {
      case UserRole.hobbyFarmer:
        return 'paywall_hobby_title'.tr();
      case UserRole.professionalFarmer:
        return 'paywall_pro_title'.tr();
      case UserRole.veterinarian:
        return 'paywall_vet_title'.tr();
      case UserRole.pharmacy:
        return 'paywall_pharmacy_title'.tr();
      case UserRole.buyer:
        return 'paywall_title'.tr();
      default:
        return 'paywall_title'.tr();
    }
  }

  String? _billingCountry(WidgetRef ref) {
    final user = ref.read(userDocProvider).valueOrNull;
    return PaymentService.resolveBillingCountryForPricing(
      paymentCountryCode: user?.paymentCountryCode ??
          PaymentService.cachedPaymentCountryCode,
    );
  }

  String? _currencyRegion(BuildContext context, WidgetRef ref) {
    final user = ref.read(userDocProvider).valueOrNull;
    final stored = ref.read(currencyRegionProvider) ?? user?.currencyRegion;
    return resolveCurrencyRegionForUser(
      locale: context.locale,
      storedRegion: stored,
      deviceCountryCode: _billingCountry(ref) ??
          PaymentService.cachedGpsVerifiedCountryCode ??
          PaymentService.cachedIpCountryCode ??
          PaymentService.cachedDeviceCountryCode,
      paymentCountryCode: user?.paymentCountryCode,
      role: user?.role,
    );
  }

  String _subscribeButtonLabel(BuildContext context, WidgetRef ref, UserRole role) {
    final lang = context.locale.languageCode;
    final billingCountry = _billingCountry(ref);
    final currencyRegion = _currencyRegion(context, ref);
    final paymentCountry = ref.read(userDocProvider).valueOrNull
            ?.paymentCountryCode ??
        PaymentService.cachedPaymentCountryCode;

    switch (role) {
      case UserRole.pharmacy:
        return PaymentService.companySubscribeButtonLabel(
          languageCode: lang,
          currencyRegion: currencyRegion,
        );
      case UserRole.hobbyFarmer:
        return PaymentService.hobbySubscribeButtonLabel(
          languageCode: lang,
          countryCode: billingCountry,
          currencyRegion: currencyRegion,
          paymentCountryCode: paymentCountry,
        );
      case UserRole.professionalFarmer:
        return PaymentService.proSubscribeButtonLabel(
          languageCode: lang,
          countryCode: billingCountry,
          currencyRegion: currencyRegion,
          paymentCountryCode: paymentCountry,
        );
      case UserRole.veterinarian:
        return PaymentService.vetSubscribeButtonLabel(
          languageCode: lang,
          currencyRegion: PaymentService.vetCurrencyRegion(
            languageCode: lang,
            currencyRegion: currencyRegion,
            countryCode: billingCountry,
          ),
          countryCode: billingCountry,
          paymentCountryCode: paymentCountry,
        );
      default:
        return _t(context, 'profile_subscription_subscribe');
    }
  }

  Future<void> _openPaywall(BuildContext context, WidgetRef ref) async {
    if (readUserAlreadySubscribed(ref)) return;

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

    if (!context.mounted) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );

    await ref.read(subscriptionServiceProvider).refreshPremiumStatus();
  }

  Future<void> _cancelSubscription(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(context, 'profile_subscription_cancel_title')),
        content: Text(_t(context, 'profile_subscription_cancel_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _t(context, 'profile_subscription_cancel_confirm'),
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    if (RevenueCatConfig.simulationMode) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(context, 'profile_subscription_cancel_sim_hint'))),
      );
      return;
    }

    final opened = await ref
        .read(subscriptionServiceProvider)
        .showManageSubscriptions();

    if (!context.mounted) return;

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(context, 'profile_subscription_cancel_failed'))),
      );
      return;
    }

    await ref.read(subscriptionServiceProvider).refreshPremiumStatus();
  }
}
