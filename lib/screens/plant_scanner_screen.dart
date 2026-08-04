import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/locale_settings_provider.dart';
import '../config/plant_scanner_config.dart';
import '../models/plant_scan_result.dart';
import '../models/product.dart';
import '../models/scan_quota.dart';
import '../models/app_user.dart';
import '../providers/subscription_provider.dart';
import '../services/plant_id_service.dart';
import '../services/payment_service.dart';
import '../services/scan_limit_service.dart';
import '../services/scan_topup_service.dart';
import '../services/sponsored_product_service.dart';
import '../repositories/scan_history_repository.dart';
import '../models/screen_guide_step.dart';
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
  final _plantIdService = PlantIdService();
  final _picker = ImagePicker();

  File? _imageFile;
  PlantScanResult? _result;
  bool _isAnalyzing = false;
  String? _errorMessage;
  ScanQuotaStatus? _quota;
  bool _isLoadingQuota = true;
  bool _isPurchasingTopUp = false;
  int? _topUpPackSize;
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
    if (localeChanged || regionChanged || _quota == null) {
      _refreshQuota();
    }
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

  Future<void> _refreshQuota() async {
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

    setState(() => _isLoadingQuota = true);

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
      packSize: packSize,
      languageCode: uiLanguage,
      currencyRegion: region,
      countryCode: billingCountry,
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
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: compact ? 8 : 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isPurchasingTopUp ? null : _purchaseScanTopUp,
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

  @override
  Widget build(BuildContext context) {
    ref.listen(premiumAccessProvider, (_, __) => _refreshQuota());

    return Scaffold(
      key: ValueKey('plant_scanner_${context.locale}'),
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('scanner_title'.tr()),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
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
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_sponsoredProducts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSponsoredSection(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLimitBanner(ScanQuotaStatus quota) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[50]!, Colors.amber[50]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[300]!),
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
                  'scanner_limit_title'.tr(),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.green[800], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _scanQuotaRemainingText(
                    remaining: monthlyRemaining,
                    limit: quota.limit,
                  ),
                  style: TextStyle(
                    color: Colors.green[900],
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
              style: TextStyle(color: Colors.green[800], fontSize: 12),
            ),
          ],
          if (_canBuyScanTopUp()) ...[
            const SizedBox(height: 4),
            Text(
              _scanTopUpHintText(),
              style: TextStyle(color: Colors.green[800], fontSize: 12),
            ),
            _buildTopUpButton(compact: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.green[100],
              child: Icon(Icons.biotech, color: Colors.green[800], size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'scanner_plant_id_title'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'scanner_subtitle'.tr(),
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  if (kDebugMode && !PlantScannerConfig.isConfigured) ...[
                    const SizedBox(height: 8),
                    Text(
                      'scanner_no_api_key'.tr(),
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
      ),
    );
  }

  Widget _buildMonthlyLimitCameraReplacement() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: KeyedSubtree(
        key: _aiImageWindowKey,
        child: Container(
          width: double.infinity,
          height: 240,
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'scanner_limit_monthly_package'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.grey[800],
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

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          KeyedSubtree(
            key: _aiImageWindowKey,
            child: Material(
              color: Colors.green[50],
              child: InkWell(
                onTap: _isAnalyzing ? null : _showImageSourcePicker,
                child: SizedBox(
                  width: double.infinity,
                  height: 240,
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                size: 56, color: Colors.green[700]),
                            const SizedBox(height: 12),
                            Text(
                              'scanner_pick_photo'.tr(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(_imageFile!, fit: BoxFit.cover),
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
                                color: Colors.black45,
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
                                        style: const TextStyle(
                                            color: Colors.white),
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
                    child: ElevatedButton.icon(
                      onPressed: _canAnalyze ? _analyzeImage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        disabledBackgroundColor: Colors.grey[400],
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: Text('scanner_new_photo'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearImage,
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
    return Card(
      color: Colors.red[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }

  Widget _buildResultCard(PlantScanResult result) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.eco, color: Colors.green[800]),
                const SizedBox(width: 8),
                Text(
                  'scanner_result'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildSponsoredSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, color: Colors.green[800]),
                const SizedBox(width: 8),
                Text(
                  farmerGuideTr(context, 'scanner_sponsored_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                        Icon(Icons.shopping_bag, color: Colors.green[700]),
                  ),
                ),
                title: Text(product.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.sellerName),
                    ProductCardPriceText(
                      price: product.price,
                      originalCurrency: product.originalCurrency,
                      unit: product.displayUnit,
                      style: TextStyle(
                        color: Colors.green[800],
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
        Icon(icon, size: 20, color: Colors.green[700]),
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
                        fontStyle:
                            isItalic ? FontStyle.italic : FontStyle.normal,
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
