import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/beta_config.dart';
import '../config/revenuecat_config.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_settings_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/payment_service.dart';
import '../services/premium_approval_service.dart';
import '../utils/company_scan_copy.dart';
import '../widgets/premium_gate.dart' show showSubscriptionPendingNotice;
import '../widgets/premium_gate_dialog.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String? _selectedProductId;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _errorMessage;
  Offerings? _offerings;

  void _closeIfAlreadySubscribed() {
    if (!mounted) return;
    if (ref.read(grantsFullPremiumProvider)) {
      Navigator.of(context).pop(true);
      return;
    }

    final user = ref.read(userDocProvider).valueOrNull ??
        ref.read(authStateProvider).valueOrNull;
    final storePremium = ref.read(isPremiumProvider).value ?? false;
    if (!userAlreadySubscribed(user: user, storePremium: storePremium)) {
      return;
    }

    if (user?.isPremiumPending == true) {
      showSubscriptionPendingNotice(context);
    }
    Navigator.of(context).pop(
      ref.read(premiumAccessProvider).hasPaidOrPromoAccess,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _closeIfAlreadySubscribed();
    });
    if (BetaConfig.closedTestFreePremium) {
      return;
    }
    _initSelection();
    _loadOfferings();
  }

  void _initSelection() {
    final user = ref.read(userDocProvider).valueOrNull ??
        ref.read(authStateProvider).valueOrNull;
    final role = user?.role ?? UserRole.buyer;
    _selectedProductId = RevenueCatConfig.recommendedProductIdForRole(role);
  }

  Future<void> _loadOfferings() async {
    if (!RevenueCatConfig.isConfigured) {
      setState(() {
        _isLoading = false;
        if (!RevenueCatConfig.simulationMode) {
          _errorMessage =
              'RevenueCat nije konfiguriran.\nDodaj REVENUECAT_ANDROID_KEY pri pokretanju app-a.';
        }
      });
      return;
    }

    try {
      final offerings =
          await ref.read(subscriptionServiceProvider).getOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (!RevenueCatConfig.simulationMode) {
            _errorMessage = 'Greška pri učitavanju ponude: $e';
          }
        });
      }
    }
  }

  Future<void> _purchase() async {
    final productId = _selectedProductId;
    if (productId == null) return;

    if (!PaymentService.hasGpsVerifiedLocation) {
      final device = await PaymentService.resolveDeviceCountryForPricing();
      if (device == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('location_install_gps_required_pay'.tr())),
        );
        return;
      }
    }

    if (RevenueCatConfig.simulationMode) {
      final lang = context.locale.languageCode;
      String? priceLabel;
      if (productId == RevenueCatConfig.licensePharmacyMonthly) {
        final quote = await ref.read(
          companySubscriptionQuoteProvider(
            CompanyQuoteRequest(
              languageCode: lang,
              currencyRegion: _effectiveCurrencyRegion(),
            ),
          ).future,
        );
        priceLabel = quote.priceLine;
      } else {
        priceLabel = RevenueCatConfig.simulationPriceLabelForProductId(
          productId,
          languageCode: lang,
          currencyRegion: _effectiveCurrencyRegion(),
          countryCode: _billingCountry(),
          paymentCountryCode: ref.read(userDocProvider).valueOrNull
                  ?.paymentCountryCode ??
              PaymentService.cachedPaymentCountryCode,
        );
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('paywall_simulate_purchase'.tr()),
          content: Text(
            priceLabel == null || priceLabel.isEmpty
                ? 'paywall_simulation_banner'.tr()
                : priceLabel,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cart_cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                foregroundColor: Colors.white,
              ),
              child: Text('paywall_simulate_purchase'.tr()),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final success = await ref
          .read(subscriptionServiceProvider)
          .purchaseProductId(productId);

      if (!mounted) return;

      if (success) {
        final user = ref.read(userDocProvider).valueOrNull ??
            ref.read(authStateProvider).valueOrNull;
        final role = user?.role ?? UserRole.buyer;

        await ref.read(premiumApprovalServiceProvider).syncSubscriptionForPurchase(
              productId: productId,
              role: role,
            );

        if (!mounted) return;

        final needsApproval =
            PremiumApprovalService.requiresAdminApproval(role) ||
                PremiumApprovalService.requiresAdminApprovalForProduct(
                  productId,
                );

        if (needsApproval) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('premium_pending_admin_approval'.tr()),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 6),
            ),
          );
        }

        Navigator.pop(context, !needsApproval);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Kupnja nije uspjela: $e');
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    if (RevenueCatConfig.simulationMode) {
      setState(() => _errorMessage = 'paywall_sim_restore_hint'.tr());
      return;
    }

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final success =
          await ref.read(subscriptionServiceProvider).restorePurchases();

      if (!mounted) return;

      if (success) {
        final user = ref.read(userDocProvider).valueOrNull ??
            ref.read(authStateProvider).valueOrNull;
        if (user != null) {
          final productId = RevenueCatConfig.recommendedProductIdForRole(user.role);
          await ref.read(premiumApprovalServiceProvider).syncSubscriptionForPurchase(
                productId: productId,
                role: user.role,
              );
        }
        Navigator.pop(context, true);
      } else {
        setState(() => _errorMessage = 'paywall_restore_empty'.tr());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'paywall_restore_failed'.tr());
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  List<String> _productIdsForRole(UserRole role) =>
      RevenueCatConfig.productIdsForRole(role);

  String? _storePriceForProduct(String productId) {
    if (_offerings == null) return null;
    for (final offering in _offerings!.all.values) {
      for (final package in offering.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          return package.storeProduct.priceString;
        }
      }
    }
    return null;
  }

  String? _billingCountry() {
    final user = ref.read(userDocProvider).valueOrNull;
    return PaymentService.resolveBillingCountryForPricing(
      paymentCountryCode: user?.paymentCountryCode ??
          PaymentService.cachedPaymentCountryCode,
    );
  }

  String? _deviceCountryForRegion() {
    return _billingCountry() ??
        PaymentService.cachedGpsVerifiedCountryCode ??
        PaymentService.cachedIpCountryCode ??
        PaymentService.cachedDeviceCountryCode;
  }

  String? _effectiveCurrencyRegion() {
    final fromProvider = ref.read(currencyRegionProvider);
    if (fromProvider != null && fromProvider.isNotEmpty) {
      return fromProvider;
    }
    final user = ref.read(userDocProvider).valueOrNull;
    return resolveCurrencyRegionForUser(
      locale: context.locale,
      storedRegion: user?.currencyRegion,
      deviceCountryCode: _deviceCountryForRegion(),
      paymentCountryCode: user?.paymentCountryCode,
      role: user?.role,
    );
  }

  String? _priceLabelForProduct(String productId) {
    final billingCountry = _billingCountry();
    final user = ref.read(userDocProvider).valueOrNull;
    final paymentCountry = user?.paymentCountryCode ??
        PaymentService.cachedPaymentCountryCode;
    if (productId == RevenueCatConfig.licensePharmacyMonthly) {
      return PaymentService.companyPriceLine(
        languageCode: context.locale.languageCode,
        currencyRegion: _effectiveCurrencyRegion(),
      );
    }
    if (productId == RevenueCatConfig.licenseVetMonthly) {
      return PaymentService.vetPriceLine(
        languageCode: context.locale.languageCode,
        currencyRegion: PaymentService.vetCurrencyRegion(
          languageCode: context.locale.languageCode,
          currencyRegion: _effectiveCurrencyRegion(),
          countryCode: billingCountry,
        ),
        countryCode: billingCountry,
        paymentCountryCode: paymentCountry,
      );
    }
    final regionalPrice = PaymentService.subscriptionPriceLineForProduct(
      productId: productId,
      languageCode: context.locale.languageCode,
      countryCode: billingCountry,
      currencyRegion: _effectiveCurrencyRegion(),
      paymentCountryCode: paymentCountry,
    );
    if (regionalPrice != null) return regionalPrice;
    if (RevenueCatConfig.simulationMode) {
      return RevenueCatConfig.simulationPriceLabelForProductId(
        productId,
        languageCode: context.locale.languageCode,
        currencyRegion: _effectiveCurrencyRegion(),
        countryCode: billingCountry,
        paymentCountryCode: paymentCountry,
      );
    }
    return _storePriceForProduct(productId);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(adminPremiumBypassProvider);
    final user = ref.watch(userDocProvider).valueOrNull ??
        ref.watch(authStateProvider).valueOrNull;
    final storePremium = ref.watch(isPremiumProvider).value ?? false;
    final alreadySubscribed =
        userAlreadySubscribed(user: user, storePremium: storePremium);

    if (isAdmin || alreadySubscribed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context, isAdmin || alreadySubscribed);
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final role = user?.role ?? UserRole.buyer;
    final productIds = _productIdsForRole(role);
    final singlePlan = productIds.length == 1;
    final companyCurrencyRegion = role == UserRole.pharmacy
        ? _effectiveCurrencyRegion()
        : null;

    if (_selectedProductId == null ||
        !productIds.contains(_selectedProductId)) {
      _selectedProductId = productIds.first;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[900]!, Colors.green[700]!, Colors.grey[50]!],
            stops: const [0.0, 0.35, 0.35],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium,
                        color: Colors.amber, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      role == UserRole.hobbyFarmer
                          ? 'paywall_hobby_title'.tr()
                          : role == UserRole.professionalFarmer
                              ? 'paywall_pro_title'.tr()
                              : role == UserRole.veterinarian
                                  ? 'paywall_vet_title'.tr()
                                  : role == UserRole.pharmacy
                                      ? 'paywall_pharmacy_title'.tr()
                                      : 'paywall_title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      role == UserRole.hobbyFarmer ||
                              role == UserRole.professionalFarmer
                          ? 'paywall_subtitle'.tr()
                          : role == UserRole.veterinarian
                              ? 'paywall_vet_features_intro'.tr()
                              : role == UserRole.pharmacy
                                  ? 'paywall_pharmacy_features_intro'.tr()
                                  : 'paywall_subtitle'.tr(),
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          children: [
                            if (RevenueCatConfig.simulationMode)
                              _simulationBanner(),
                            Text(
                              singlePlan
                                  ? 'paywall_your_plan'.tr()
                                  : 'paywall_select_plan'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...productIds.map(
                              (id) => _productPlanTile(
                                id,
                                selectable: !singlePlan,
                                showFeatures: !_showsDetailedBenefits(role),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (role == UserRole.veterinarian) ...[
                              Text(
                                'paywall_vet_features_intro'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const VetPremiumBenefitsList(),
                            ] else if (role == UserRole.pharmacy) ...[
                              Text(
                                'paywall_pharmacy_features_intro'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const CompanyPremiumBenefitsList(),
                            ] else if (role == UserRole.hobbyFarmer) ...[
                              Text(
                                'paywall_hobby_features_intro'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const HobbyPremiumBenefitsList(),
                            ] else if (role == UserRole.professionalFarmer) ...[
                              Text(
                                'paywall_pro_features_intro'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const ProPremiumBenefitsList(),
                            ] else ...[
                              _benefitTile(
                                Icons.shopping_bag_outlined,
                                'paywall_benefit_orders'.tr(),
                                'paywall_benefit_orders_desc'.tr(),
                              ),
                              _benefitTile(
                                Icons.chat_bubble_outline,
                                'paywall_benefit_chat'.tr(),
                                'paywall_benefit_chat_desc'.tr(),
                              ),
                              _benefitTile(
                                Icons.biotech_outlined,
                                'paywall_benefit_scanner'.tr(),
                                'paywall_benefit_scanner_desc'.tr(),
                              ),
                            ],
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isPurchasing ||
                                        _selectedProductId == null
                                    ? null
                                    : _purchase,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isPurchasing
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : RevenueCatConfig.simulationMode
                                        ? Text(
                                            'paywall_simulate_purchase'.tr(),
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : role == UserRole.pharmacy
                                            ? Text(
                                                PaymentService
                                                    .companySubscribeButtonLabel(
                                                  languageCode: context
                                                      .locale.languageCode,
                                                  currencyRegion:
                                                      companyCurrencyRegion,
                                                ),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : role == UserRole.hobbyFarmer
                                                ? Text(
                                                    PaymentService
                                                        .hobbySubscribeButtonLabel(
                                                      languageCode: context
                                                          .locale.languageCode,
                                                      countryCode:
                                                          _billingCountry(),
                                                      currencyRegion:
                                                          _effectiveCurrencyRegion(),
                                                      paymentCountryCode: user
                                                              ?.paymentCountryCode ??
                                                          PaymentService
                                                              .cachedPaymentCountryCode,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  )
                                                : role ==
                                                        UserRole
                                                            .professionalFarmer
                                                    ? Text(
                                                        PaymentService
                                                            .proSubscribeButtonLabel(
                                                          languageCode: context
                                                              .locale
                                                              .languageCode,
                                                          countryCode:
                                                              _billingCountry(),
                                                          currencyRegion:
                                                              _effectiveCurrencyRegion(),
                                                          paymentCountryCode: user
                                                                  ?.paymentCountryCode ??
                                                              PaymentService
                                                                  .cachedPaymentCountryCode,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          fontSize: 17,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      )
                                                    : Text(
                                                        'paywall_start_premium'
                                                            .tr(),
                                                        style: const TextStyle(
                                                          fontSize: 17,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _isPurchasing ? null : _restore,
                              child: Text('paywall_restore'.tr()),
                            ),
                            Text(
                              RevenueCatConfig.simulationMode
                                  ? 'paywall_sim_footer'.tr()
                                  : 'paywall_prod_footer'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _simulationBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: Colors.amber.shade900),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'paywall_simulation_banner'.tr(),
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _showsDetailedBenefits(UserRole role) =>
      role == UserRole.hobbyFarmer ||
      role == UserRole.professionalFarmer ||
      role == UserRole.veterinarian ||
      role == UserRole.pharmacy;

  String _featuresTextForProduct(String? featuresKey) {
    if (featuresKey == null) return '';
    if (featuresKey == 'paywall_pharmacy_features') {
      final user = ref.read(userDocProvider).valueOrNull ??
          ref.read(authStateProvider).valueOrNull;
      return companyPharmacyFeaturesForContext(
        context,
        currencyRegion: ref.read(currencyRegionProvider) ?? user?.currencyRegion,
        paymentCountryCode: user?.paymentCountryCode,
      );
    }
    return featuresKey.tr();
  }

  Widget _productPlanTile(
    String productId, {
    required bool selectable,
    bool showFeatures = true,
  }) {
    final isSelected = _selectedProductId == productId;
    final titleKey = RevenueCatConfig.titleKeyForProductId(productId);
    final priceKey = RevenueCatConfig.priceKeyForProductId(productId);
    final featuresKey = RevenueCatConfig.featuresKeyForProductId(productId);
    final storePrice = _priceLabelForProduct(productId);
    final featuresText = _featuresTextForProduct(featuresKey);

    final content = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected || !selectable
              ? Colors.green[700]!
              : Colors.grey[300]!,
          width: isSelected || !selectable ? 2 : 1,
        ),
        color: isSelected || !selectable ? Colors.green[50] : Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectable)
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: isSelected ? Colors.green[800] : Colors.grey,
            ),
          if (selectable) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleKey != null ? titleKey.tr() : productId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (priceKey != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    storePrice ?? priceKey.tr(),
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ],
                if (showFeatures && featuresKey != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    featuresText,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
                if (RevenueCatConfig.simulationMode) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ID: $productId',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!selectable) return content;

    return GestureDetector(
      onTap: () => setState(() => _selectedProductId = productId),
      child: content,
    );
  }

  Widget _benefitTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.green[800]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green[600], size: 22),
        ],
      ),
    );
  }
}
