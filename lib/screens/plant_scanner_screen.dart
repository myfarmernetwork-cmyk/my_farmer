import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/locale_settings_provider.dart';
import '../config/plant_scanner_config.dart';
import '../models/plant_scan_result.dart';
import '../models/premium_access.dart';
import '../models/product.dart';
import '../models/scan_quota.dart';
import '../models/app_user.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../services/plant_id_service.dart';
import '../services/payment_service.dart';
import '../services/scan_limit_service.dart';
import '../config/revenuecat_config.dart';
import '../services/scan_topup_service.dart';
import '../services/sponsored_product_service.dart';
import '../repositories/scan_history_repository.dart';
import '../models/screen_guide_step.dart';
import '../theme/agro_accent_colors.dart';
import '../utils/scroll_bottom_padding.dart';
import '../widgets/agro_glass_chrome.dart';
import '../widgets/farmer_helper_button.dart';
import '../widgets/farmer_help_widgets.dart';
import '../widgets/product_card.dart';
import '../widgets/translated_text.dart';
import 'scan_history_screen.dart';

class PlantScannerScreen extends ConsumerStatefulWidget {
  const PlantScannerScreen({super.key});

  @override
  ConsumerState<PlantScannerScreen> createState() =>
      _PlantScannerScreenState();
}

class _PlantScannerScreenState extends ConsumerState<PlantScannerScreen> {
  static const _chipGreen = AgroAccentColors.marketplaceChipGreen;
  static const _priceYellow = Color(0xFFFFEB3B);

  final _plantIdService = PlantIdService();
  final _picker = ImagePicker();

  File? _imageFile;
  PlantScanResult? _result;
  bool _isAnalyzing = false;
  String? _errorMessage;
  ScanQuotaStatus? _quota;
  bool _isLoadingQuota = true;
  bool _isPurchasingTopUp = false;
  bool _isRefreshingQuota = false;
  bool _quotaRefreshScheduled = false;
  int? _topUpPackSize;
  String? _topUpStorePrice;
  Locale? _trackedLocale;
  String? _trackedBillingRegion;
  List<Product> _sponsoredProducts = [];
  bool _loadingSponsored = false;

  final GlobalKey _aiHistoryKey = GlobalKey();
  final GlobalKey _aiLimitKey = GlobalKey();
  final GlobalKey _aiImageWindowKey = GlobalKey();
  final GlobalKey _aiAnalyzeButtonKey = GlobalKey();

  List<ScreenGuideStep> get _guideSteps => [
        ScreenGuideStep(
          targetKey: _aiHistoryKey,
          titleKey: 'guide_ai_history_title',
          bodyKey: 'guide_ai_history_body',
        ),
        ScreenGuideStep(
          targetKey: _aiLimitKey,
          titleKey: 'guide_ai_quota_title',
          bodyKey: 'guide_ai_quota_body',
        ),
        ScreenGuideStep(
          targetKey: _aiImageWindowKey,
          titleKey: 'guide_ai_image_window_title',
          bodyKey: 'guide_ai_image_window_body',
        ),
        ScreenGuideStep(
          targetKey: _aiAnalyzeButtonKey,
          titleKey: 'guide_ai_analyze_title',
          bodyKey: 'guide_ai_analyze_body',
        ),
      ];

  @override
  void initState() {
    super.initState();
    _purgeOldScans();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQuota();
      _loadTopUpStorePrice();
    });
  }

  Future<void> _loadTopUpStorePrice() async {
    try {
      final price = await ref
          .read(subscriptionServiceProvider)
          .storePriceStringForProductId(RevenueCatConfig.scanTopUpPack);
      if (!mounted || price == null || price.trim().isEmpty) return;
      setState(() => _topUpStorePrice = price.trim());
    } catch (_) {
      // Fallback ostaje PaymentService.scanTopUpPackPriceEur (7,50 €).
    }
  }

  Future<void> _purgeOldScans() async {
    await ref.read(scanHistoryRepositoryProvider).purgeExpiredEntries();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = context.locale;
    final region = ref.read(currencyRegionProvider);
    final localeChanged = _trackedLocale != locale;
    final regionChanged = _trackedBillingRegion != region;
    _trackedLocale = locale;
    _trackedBillingRegion = region;
    _syncCurrencyRegionFromProfile();
    if (localeChanged || regionChanged) {
      _scheduleQuotaRefresh();
    } else if (_quota == null) {
      _refreshQuota(showLoading: true);
    }
  }

  bool _scanQuotaUserChanged(AppUser? previous, AppUser? next) {
    if (previous?.uid != next?.uid) return true;
    if (previous == null || next == null) return previous != next;

    bool fieldChanged(String? a, String? b) => (a ?? '') != (b ?? '');

    return fieldChanged(previous.subscriptionTier, next.subscriptionTier) ||
        fieldChanged(
          previous.premiumApprovalStatus,
          next.premiumApprovalStatus,
        ) ||
        fieldChanged(previous.requestedPremiumTier, next.requestedPremiumTier) ||
        fieldChanged(previous.currencyRegion, next.currencyRegion) ||
        fieldChanged(previous.paymentCountryCode, next.paymentCountryCode) ||
        previous.premiumActive != next.premiumActive ||
        previous.isPremiumApproved != next.isPremiumApproved ||
        previous.isInPromotionalPeriod != next.isInPromotionalPeriod ||
        previous.hasFreeScans != next.hasFreeScans ||
        previous.isTrialUsed != next.isTrialUsed ||
        previous.introScansUsed != next.introScansUsed ||
        previous.role != next.role;
  }

  bool _scanQuotaAccessChanged(PremiumAccess? previous, PremiumAccess? next) {
    if (previous == null || next == null) return previous != next;
    return previous.isPremium != next.isPremium ||
        previous.isAdminBypass != next.isAdminBypass ||
        previous.closedTestFreePremium != next.closedTestFreePremium ||
        previous.closedTestingFreeAiScanner !=
            next.closedTestingFreeAiScanner ||
        previous.effectiveRole != next.effectiveRole ||
        previous.canUse(PremiumFeature.aiScanner) !=
            next.canUse(PremiumFeature.aiScanner);
  }

  void _scheduleQuotaRefresh() {
    if (_quotaRefreshScheduled) return;
    _quotaRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quotaRefreshScheduled = false;
      if (mounted) {
        unawaited(_refreshQuota());
      }
    });
  }

  String? _effectiveCurrencyRegion() {
    final fromProvider = ref.read(currencyRegionProvider);
    if (fromProvider != null && fromProvider.isNotEmpty) {
      return fromProvider;
    }
    final fromUser = ref.read(userDocProvider).valueOrNull?.currencyRegion;
    if (fromUser != null && fromUser.isNotEmpty) return fromUser;
    return null;
  }

  void _syncCurrencyRegionFromProfile() {
    final user = ref.read(userDocProvider).valueOrNull;
    final role = user?.role ?? UserRole.buyer;
    final billingCountry = PaymentService.resolveBillingCountryForPricing(
      paymentCountryCode: user?.paymentCountryCode ??
          PaymentService.cachedPaymentCountryCode,
    );
    final resolved = resolveCurrencyRegionForUser(
      locale: context.locale,
      storedRegion: user?.currencyRegion,
      deviceCountryCode: billingCountry ??
          PaymentService.cachedGpsVerifiedCountryCode ??
          PaymentService.cachedIpCountryCode ??
          PaymentService.cachedDeviceCountryCode,
      paymentCountryCode: user?.paymentCountryCode ??
          PaymentService.cachedPaymentCountryCode,
      role: role,
    );
    if (ref.read(currencyRegionProvider) != resolved) {
      ref.read(currencyRegionProvider.notifier).state = resolved;
    }
  }

  Future<void> _refreshQuota({bool showLoading = false}) async {
    if (_isRefreshingQuota) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _quota = null;
          _isLoadingQuota = false;
        });
      }
      return;
    }

    _isRefreshingQuota = true;
    final shouldShowLoading = showLoading || _quota == null;
    if (shouldShowLoading && mounted) {
      setState(() => _isLoadingQuota = true);
    }

    try {
      final access = ref.read(premiumAccessProvider);
      final status = await ref.read(scanLimitServiceProvider).getQuotaStatus(
            userId: user.uid,
            access: access,
          );
      final packSize = await ref
          .read(scanLimitServiceProvider)
          .resolveTopUpPackSizeForAccess(access);
      if (mounted) {
        setState(() {
          _quota = status;
          _topUpPackSize = packSize;
          _isLoadingQuota = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingQuota = false);
      }
    } finally {
      _isRefreshingQuota = false;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
    );

    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null || _quota != null && !_quota!.canScan) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final scanLanguage = context.locale.languageCode;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final access = ref.read(premiumAccessProvider);
      final quota = await ref.read(scanLimitServiceProvider).checkBeforeScan(
            userId: user.uid,
            access: access,
          );

      if (!quota.canScan) {
        if (mounted) {
          setState(() {
            _quota = quota;
            _errorMessage = _limitMessage(quota);
          });
        }
        return;
      }

      final result = await _plantIdService.identifyPlant(
        _imageFile!,
        language: scanLanguage,
      );

      await ref.read(scanLimitServiceProvider).recordScan(
            userId: user.uid,
            access: access,
          );

      await ref.read(scanHistoryRepositoryProvider).saveScan(
            imageFile: _imageFile!,
            result: result,
          );

      await _refreshQuota();

      if (mounted) {
        setState(() => _result = result);
        await _loadSponsoredProducts(result.commonName);
      }
    } on PlantScannerException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.messageKey.tr(namedArgs: e.namedArgs));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '${'scanner_error'.tr()}: $e');
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _loadSponsoredProducts(String? plantName) async {
    setState(() => _loadingSponsored = true);
    try {
      final products = await ref
          .read(sponsoredProductServiceProvider)
          .fetchSponsoredBelowScan(plantName: plantName);
      if (mounted) {
        setState(() {
          _sponsoredProducts = products;
          _loadingSponsored = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSponsored = false);
    }
  }

  String _limitTitle(ScanQuotaStatus quota) {
    switch (quota.blockReasonKey) {
      case 'premium_pending_admin_approval':
        return 'scanner_pending_verification'.tr();
      case 'scanner_subscription_required':
      case 'scanner_intro_exhausted':
        return 'scanner_limit_title'.tr();
      default:
        return 'scanner_limit_title'.tr();
    }
  }

  String _limitMessage(ScanQuotaStatus quota) {
    final key = quota.blockReasonKey ?? 'scanner_limit_monthly';
    return key.tr();
  }

  bool _isLegacyScanTopUpHint(String hint) {
    if (hint == 'scanner_topup_hint') return true;
    final lower = hint.toLowerCase();
    return lower.contains('0,15') ||
        lower.contains('0.15') ||
        lower.contains('po skenu') ||
        lower.contains('per scan') ||
        lower.contains('pro sken') ||
        lower.contains('pretplaćeni') ||
        lower.contains('pretplaceni') ||
        lower.contains('nižoj cijeni') ||
        lower.contains('nizoj cijeni') ||
        lower.contains('pola mjesečnog') ||
        lower.contains('cijena u valuti') ||
        lower.contains('prilagođeno vašoj regiji');
  }

  String _scanTopUpHintText() {
    var hint = 'scanner_topup_hint'.tr();
    if (!_isLegacyScanTopUpHint(hint)) return hint;
    return farmerGuideTr(context, 'scanner_topup_hint');
  }

  String _scanQuotaRemainingText({
    required int remaining,
    required int limit,
  }) {
    var text = 'scanner_quota_remaining'.tr(
      namedArgs: {
        'remaining': '$remaining',
        'limit': '$limit',
      },
    );
    if (text != 'scanner_quota_remaining' &&
        !text.contains('Preostala skeniranja u periodu') &&
        !text.contains('Remaining scans in period')) {
      return text;
    }
    final lang = farmerGuideLangCode(context);
    final template = kFarmerGuideFallbacks['scanner_quota_remaining']?[lang] ??
        kFarmerGuideFallbacks['scanner_quota_remaining']?['hr'] ??
        'Preostalo skenova ovaj mjesec: {remaining} / {limit}';
    return template
        .replaceAll('{remaining}', '$remaining')
        .replaceAll('{limit}', '$limit');
  }

  bool _canBuyScanTopUp() {
    if (ref.read(adminPremiumBypassProvider)) return false;
    final access = ref.read(premiumAccessProvider);
    return ref.read(scanTopUpServiceProvider).canPurchaseTopUp(access) &&
        _quota?.tier == ScanLimitTier.monthly;
  }

  Future<void> _purchaseScanTopUp() async {
    if (_isPurchasingTopUp) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final access = ref.read(premiumAccessProvider);
    if (!_canBuyScanTopUp()) return;

    final languageCode = context.locale.languageCode;
    final region = _effectiveCurrencyRegion() ??
        ref.read(currencyRegionProvider);

    setState(() => _isPurchasingTopUp = true);
    try {
      final packSize = _topUpPackSize ??
          await ref.read(scanTopUpServiceProvider).resolvePackSize(access);
      final ok = await ref.read(scanTopUpServiceProvider).purchaseTopUpPack(
            userId: user.uid,
            access: access,
            languageCode: languageCode,
            currencyRegion: region,
          );
      if (!mounted) return;
      if (ok) {
        await _refreshQuota();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'scanner_topup_success'.tr(namedArgs: {'count': '$packSize'}),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('scanner_topup_failed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasingTopUp = false);
    }
  }

  Widget _buildTopUpButton({bool compact = false}) {
    if (!_canBuyScanTopUp()) return const SizedBox.shrink();

    ref.watch(currencyRegionProvider);
    ref.watch(userDocProvider);
    final uiLanguage = context.locale.languageCode;
    final user = ref.watch(userDocProvider).valueOrNull;
    final billingCountry = PaymentService.resolveBillingCountryForPricing(
      paymentCountryCode: user?.paymentCountryCode ??
          PaymentService.cachedPaymentCountryCode,
    );
    final region = resolveCurrencyRegionForUser(
      locale: context.locale,
      storedRegion: user?.currencyRegion,
      deviceCountryCode: billingCountry ??
          PaymentService.cachedGpsVerifiedCountryCode ??
          PaymentService.cachedIpCountryCode ??
          PaymentService.cachedDeviceCountryCode,
      paymentCountryCode: user?.paymentCountryCode ??
          PaymentService.cachedPaymentCountryCode,
      role: user?.role ?? UserRole.buyer,
    );
    final access = ref.read(premiumAccessProvider);
    final monthlyLimit = _quota?.limit ?? access.monthlyScanLimit();
    final packSize = _topUpPackSize ??
        PaymentService.topUpPackSizeFromMonthlyLimit(monthlyLimit);
    if (packSize <= 0) return const SizedBox.shrink();

    final price = PaymentService.scanTopUpPackPriceLine(
      languageCode: uiLanguage,
      currencyRegion: region,
      countryCode: billingCountry,
      storePriceOverride: _topUpStorePrice,
    );
    var label = 'scanner_topup_button'.tr(
      namedArgs: {
        'count': '$packSize',
        'price': price,
      },
    );
    if (label == 'scanner_topup_button') {
      label = PaymentService.scanTopUpButtonLabel(
        packSize: packSize,
        languageCode: uiLanguage,
        currencyRegion: region,
        countryCode: billingCountry,
        storePriceOverride: _topUpStorePrice,
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: compact ? 8 : 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isPurchasingTopUp ? null : _purchaseScanTopUp,
          style: FilledButton.styleFrom(
            backgroundColor: _chipGreen,
            foregroundColor: _priceYellow,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AgroAccentColors.marketplacePillRadius,
              ),
            ),
          ),
          icon: _isPurchasingTopUp
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_circle_outline, size: 20),
          label: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: compact ? 13 : 14),
          ),
        ),
      ),
    );
  }

  void _clearImage() {
    setState(() {
      _imageFile = null;
      _result = null;
      _errorMessage = null;
      _sponsoredProducts = [];
    });
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.green),
              title: Text('scanner_camera'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: Text('scanner_gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool get _canAnalyze {
    if (_imageFile == null || _isAnalyzing || _isLoadingQuota) return false;
    if (_quota != null && !_quota!.canScan) return false;
    return true;
  }

  Widget _marketplacePanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    BoxDecoration? decoration,
  }) {
    return Container(
      width: double.infinity,
      decoration: decoration ??
          BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              AgroAccentColors.marketplaceCornerRadius,
            ),
            border: Border.all(color: _chipGreen.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
      child: Padding(padding: padding, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userDocProvider, (previous, next) {
      if (_scanQuotaUserChanged(
        previous?.valueOrNull,
        next.valueOrNull,
      )) {
        _scheduleQuotaRefresh();
      }
    });
    ref.listen(premiumAccessProvider, (previous, next) {
      if (_scanQuotaAccessChanged(previous, next)) {
        _scheduleQuotaRefresh();
      }
    });

    return Scaffold(
      key: ValueKey('plant_scanner_${context.locale}'),
      backgroundColor: AgroAccentColors.marketplaceUnifiedGreen,
      appBar: AgroGlassAppBar(
        unifiedMarketplaceHeader: true,
        title: Text('scanner_title'.tr()),
        actions: [
          KeyedSubtree(
            key: _aiHistoryKey,
            child: IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'scan_history_title'.tr(),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanHistoryScreen()),
              ),
            ),
          ),
          FarmerHelperIconButton(guideSteps: _guideSteps),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AgroAccentColors.marketplaceUnifiedBackgroundGradient,
        ),
        child: RefreshIndicator(
          color: _chipGreen,
          onRefresh: () => _refreshQuota(showLoading: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: ScrollBottomPadding.list(
              context,
              mainTab: true,
              base: const EdgeInsets.all(16),
            ),
            children: [
          _buildInfoCard(),
          KeyedSubtree(
            key: _aiLimitKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_quota != null && _quota!.limit > 0) ...[
                  const SizedBox(height: 16),
                  _buildQuotaBanner(_quota!),
                  if (!_quota!.canScan &&
                      _quota!.blockReasonKey != 'scanner_limit_monthly_package') ...[
                    const SizedBox(height: 12),
                    _buildLimitBanner(_quota!),
                  ],
                ] else if (_quota != null && !_quota!.canScan) ...[
                  const SizedBox(height: 16),
                  _buildLimitBanner(_quota!),
                ] else
                  const SizedBox(height: 1),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildImageSection(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorCard(_errorMessage!),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _buildResultCard(_result!),
            if (_loadingSponsored)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(
                  child: CircularProgressIndicator(color: _chipGreen),
                ),
              )
            else if (_sponsoredProducts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSponsoredSection(),
            ],
          ],
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildLimitBanner(ScanQuotaStatus quota) {
    return _marketplacePanel(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AgroAccentColors.marketplaceCornerRadius),
        border: Border.all(color: Colors.orange.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, color: Colors.orange[800], size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _limitTitle(quota),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange[900],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _limitMessage(quota),
                  style: TextStyle(
                    color: Colors.orange[900],
                    height: 1.45,
                    fontSize: 14,
                  ),
                ),
                _buildTopUpButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaBanner(ScanQuotaStatus quota) {
    final isAdmin = ref.watch(adminPremiumBypassProvider);

    if (isAdmin) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.orange.shade800, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Admin — neograničeno AI skeniranje',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final monthlyRemaining =
        (quota.limit - quota.used).clamp(0, quota.limit);
    final bonusNote = quota.bonusRemaining > 0
        ? 'scanner_quota_bonus'.tr(
            namedArgs: {'bonus': '${quota.bonusRemaining}'},
          )
        : null;

    return _marketplacePanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: _chipGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _scanQuotaRemainingText(
                    remaining: monthlyRemaining,
                    limit: quota.limit,
                  ),
                  style: const TextStyle(
                    color: _chipGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (bonusNote != null) ...[
            const SizedBox(height: 4),
            Text(
              bonusNote,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          if (_canBuyScanTopUp()) ...[
            const SizedBox(height: 4),
            Text(
              _scanTopUpHintText(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            _buildTopUpButton(compact: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return _marketplacePanel(
      child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _chipGreen.withValues(alpha: 0.14),
              child: const Icon(Icons.biotech, color: _chipGreen, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'scanner_plant_id_title'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _chipGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'scanner_subtitle'.tr(),
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  if (!PlantScannerConfig.isConfigured) ...[
                    const SizedBox(height: 8),
                    Text(
                      PlantScannerConfig.useCloudFunction
                          ? farmerGuideTr(
                              context,
                              'scanner_cloud_unavailable',
                              fallbacks: const {
                                'hr':
                                    'AI skener koristi cloud — pokrenite app s PLANT_SCANNER_USE_CLOUD=true ili scripts/run_dev.ps1',
                                'de':
                                    'KI-Scanner nutzt Cloud — starten Sie die App mit PLANT_SCANNER_USE_CLOUD=true.',
                                'en':
                                    'AI scanner uses cloud — run with PLANT_SCANNER_USE_CLOUD=true or run_dev.ps1.',
                              },
                            )
                          : 'scanner_no_api_key'.tr(),
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildMonthlyLimitCameraReplacement() {
    return _marketplacePanel(
      padding: EdgeInsets.zero,
      child: KeyedSubtree(
        key: _aiImageWindowKey,
        child: Container(
          width: double.infinity,
          height: 240,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(
              AgroAccentColors.marketplaceCornerRadius - 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy,
                size: 48,
                color: _chipGreen.withValues(alpha: 0.65),
              ),
              const SizedBox(height: 16),
              Text(
                'scanner_limit_monthly_package'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              _buildTopUpButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    if (_quota != null &&
        !_quota!.canScan &&
        _quota!.blockReasonKey == 'scanner_limit_monthly_package') {
      return _buildMonthlyLimitCameraReplacement();
    }

    return _marketplacePanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          KeyedSubtree(
            key: _aiImageWindowKey,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isAnalyzing ? null : _showImageSourcePicker,
                borderRadius: BorderRadius.circular(
                  AgroAccentColors.marketplaceCornerRadius,
                ),
                child: Container(
                  width: double.infinity,
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(
                      AgroAccentColors.marketplaceCornerRadius - 2,
                    ),
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_a_photo,
                              size: 56,
                              color: _chipGreen,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'scanner_pick_photo'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _chipGreen,
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AgroAccentColors.marketplaceCornerRadius - 2,
                              ),
                              child: Image.file(_imageFile!, fit: BoxFit.cover),
                            ),
                            if (!_isAnalyzing)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: IconButton(
                                    tooltip: 'scanner_clear_photo'.tr(),
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: _clearImage,
                                  ),
                                ),
                              ),
                            if (_isAnalyzing)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(
                                    AgroAccentColors.marketplaceCornerRadius - 2,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'scanner_analyzing'.tr(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: KeyedSubtree(
              key: _aiAnalyzeButtonKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _canAnalyze ? _analyzeImage : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _chipGreen,
                        disabledBackgroundColor: Colors.grey.shade400,
                        foregroundColor: _priceYellow,
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AgroAccentColors.marketplacePillRadius,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.search),
                      label: Text('scanner_analyze'.tr()),
                    ),
                  ),
                  if (_imageFile != null && !_isAnalyzing) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showImageSourcePicker,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _chipGreen,
                              side: BorderSide(
                                color: _chipGreen.withValues(alpha: 0.5),
                              ),
                            ),
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: Text('scanner_new_photo'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearImage,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _chipGreen,
                              side: BorderSide(
                                color: _chipGreen.withValues(alpha: 0.5),
                              ),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: Text('scanner_clear_photo'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return _marketplacePanel(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(AgroAccentColors.marketplaceCornerRadius),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.red[900]),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildResultCard(PlantScanResult result) {
    return _marketplacePanel(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.eco, color: _chipGreen),
                const SizedBox(width: 8),
                Text(
                  'scanner_result'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _chipGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!result.isPlant)
              _warningBanner('scanner_not_plant_warning'.tr())
            else ...[
              _resultRow(
                'scanner_common_name'.tr(),
                result.commonName ?? 'scanner_not_recognized'.tr(),
                Icons.label_outline,
                translateValue: result.commonName != null,
              ),
              const SizedBox(height: 10),
              _resultRow(
                'scanner_scientific_name'.tr(),
                result.scientificName ?? 'scanner_not_recognized'.tr(),
                Icons.menu_book_outlined,
                isItalic: true,
              ),
              const SizedBox(height: 10),
              _resultRow(
                'scanner_confidence'.tr(),
                '${(result.identificationConfidence * 100).toStringAsFixed(1)}%',
                Icons.verified_outlined,
              ),
            ],
            const Divider(height: 28),
            _buildHealthSection(result),
          ],
        ),
    );
  }

  Widget _buildSponsoredSection() {
    return _marketplacePanel(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, color: _chipGreen),
                const SizedBox(width: 8),
                Text(
                  farmerGuideTr(context, 'scanner_sponsored_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _chipGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              farmerGuideTr(context, 'scanner_sponsored_desc'),
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 12),
            ..._sponsoredProducts.map(
              (product) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.shopping_bag, color: _chipGreen),
                  ),
                ),
                title: Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _chipGreen,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.sellerName,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    ProductCardPriceText(
                      price: product.price,
                      originalCurrency: product.originalCurrency,
                      unit: product.displayUnit,
                      style: const TextStyle(
                        color: _chipGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildHealthSection(PlantScanResult result) {
    if (result.isHealthy == null && result.diseases.isEmpty) {
      return Text(
        'scanner_health_unavailable'.tr(),
        style: TextStyle(color: Colors.grey[600]),
      );
    }

    final isHealthy = result.isHealthy ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
              color: isHealthy ? Colors.green : Colors.orange[800],
            ),
            const SizedBox(width: 8),
            Text(
              isHealthy
                  ? 'scanner_plant_healthy'.tr()
                  : 'scanner_problems_detected'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isHealthy ? Colors.green[800] : Colors.orange[900],
              ),
            ),
          ],
        ),
        if (result.healthProbability != null) ...[
          const SizedBox(height: 6),
          Text(
            'scanner_health_probability'.tr(namedArgs: {
              'percent': (result.healthProbability! * 100).toStringAsFixed(0),
            }),
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
        if (result.hasDiseaseSuggestions) ...[
          const SizedBox(height: 16),
          Text(
            'scanner_possible_diseases'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...result.diseases.take(3).map(_buildDiseaseTile),
        ],
      ],
    );
  }

  Widget _buildDiseaseTile(PlantDiseaseSuggestion disease) {
    final primaryName = disease.localName?.isNotEmpty == true
        ? disease.localName!
        : disease.name;
    final showSecondaryName = disease.name.isNotEmpty &&
        disease.localName != null &&
        disease.localName!.isNotEmpty &&
        disease.name.toLowerCase() != disease.localName!.toLowerCase();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            primaryName.isNotEmpty ? primaryName : 'scanner_not_recognized'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (showSecondaryName)
            TranslatedText(
              disease.name,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            )
          else if (disease.name.isNotEmpty && primaryName.isEmpty)
            TranslatedText(
              disease.name,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'scanner_probability_label'.tr(namedArgs: {
              'percent': (disease.probability * 100).toStringAsFixed(1),
            }),
            style: TextStyle(color: Colors.orange[900], fontSize: 13),
          ),
          if (disease.description != null) ...[
            const SizedBox(height: 6),
            TranslatedText(
              disease.description!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          if (disease.treatment != null) ...[
            const SizedBox(height: 6),
            Text(
              'scanner_treatment_label'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green[800],
                fontSize: 13,
              ),
            ),
            TranslatedText(
              disease.treatment!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultRow(
    String label,
    String value,
    IconData icon, {
    bool isItalic = false,
    bool translateValue = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _chipGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              translateValue
                  ? TranslatedText(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _chipGreen,
                        fontStyle:
                            isItalic ? FontStyle.italic : FontStyle.normal,
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _chipGreen,
                        fontStyle:
                            isItalic ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _warningBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber[800]),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
