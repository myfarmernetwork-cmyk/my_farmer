import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/subscription_limits.dart';
import '../models/app_user.dart';
import '../models/premium_access.dart';
import '../models/scan_market_limits.dart';
import '../models/scan_quota.dart';
import '../models/subscription_tier.dart';
import '../providers/locale_settings_provider.dart';
import 'payment_service.dart';
import 'scan_topup_service.dart';

class ScanLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserQuotaDoc(
    String userId,
  ) async {
    final ref = _firestore.collection('users').doc(userId);
    try {
      return await ref.get(const GetOptions(source: Source.server));
    } catch (_) {
      return ref.get();
    }
  }

  _UserQuotaSnapshot _quotaSnapshot(Map<String, dynamic> data) {
    return _UserQuotaSnapshot(
      scansThisMonth: _asInt(data['scansThisMonth']),
      introScansUsed: _asInt(data['introScansUsed']),
      bonusRemaining: _asInt(data[ScanTopUpService.bonusScansField]),
      hasFreeScans: data['hasFreeScans'] != false,
      isTrialUsed: data['isTrialUsed'] == true,
      lastScanReset: _asDateTime(data['lastScanReset']),
    );
  }

  bool _usingIntro({
    required _UserQuotaSnapshot quota,
    required PremiumAccess access,
    required Map<String, dynamic> serverData,
  }) {
    if (_hasPaidOrPromoFromServer(access, serverData)) return false;
    return quota.hasFreeScans &&
        !quota.isTrialUsed &&
        quota.introScansUsed < SubscriptionLimits.introAiScansTotal;
  }

  SubscriptionTier? _resolvedBusinessTier(Map<String, dynamic> data) {
    return _tierOnServer(data) ??
        SubscriptionTierX.fromFirestore(
          data['requestedPremiumTier']?.toString(),
        );
  }

  bool _needsAdminVerification(UserRole role) =>
      role == UserRole.veterinarian || role == UserRole.pharmacy;

  bool _isPremiumApprovedOnServer(Map<String, dynamic> data) {
    final status = data['premiumApprovalStatus']?.toString().trim().toUpperCase();
    return status == 'APPROVED';
  }

  SubscriptionTier? _tierOnServer(Map<String, dynamic> data) {
    return SubscriptionTierX.fromFirestore(data['subscriptionTier']?.toString());
  }

  bool _hasPaidOrPromoFromServer(
    PremiumAccess access,
    Map<String, dynamic> data,
  ) {
    if (access.grantsFullPremium) return true;
    if (_isPremiumApprovedOnServer(data)) {
      return true;
    }
    return access.hasPaidOrPromoAccess;
  }

  bool _canUseAiScannerFromServer({
    required PremiumAccess access,
    required Map<String, dynamic> serverData,
    required _UserQuotaSnapshot quota,
  }) {
    if (access.grantsFullPremium) return true;
    if (access.canUse(PremiumFeature.aiScanner)) return true;

    final role = access.role;
    final approved = _isPremiumApprovedOnServer(serverData);
    final tier = _resolvedBusinessTier(serverData);

    if (role == UserRole.pharmacy &&
        approved &&
        SubscriptionLimits.hasBusinessLicense(tier)) {
      return true;
    }
    if (role == UserRole.pharmacy &&
        (access.isPremium || access.user?.premiumActive == true)) {
      return true;
    }
    if (role == UserRole.veterinarian &&
        approved) {
      return true;
    }

    if (quota.hasFreeScans &&
        !quota.isTrialUsed &&
        quota.introScansUsed < SubscriptionLimits.introAiScansTotal &&
        !_hasPaidOrPromoFromServer(access, serverData)) {
      return true;
    }

    return false;
  }

  String? _blockReasonFromServer({
    required PremiumAccess access,
    required Map<String, dynamic> serverData,
    required _UserQuotaSnapshot quota,
  }) {
    final pending =
        access.user?.isPremiumPending == true ||
        serverData['premiumApprovalStatus']?.toString().toUpperCase() ==
            'PENDING';
    if (pending &&
        (access.role == UserRole.pharmacy ||
            access.role == UserRole.veterinarian)) {
      return 'premium_pending_admin_approval';
    }
    if (!quota.hasFreeScans) {
      return 'scanner_device_trial_used';
    }
    if (quota.introScansUsed >= SubscriptionLimits.introAiScansTotal) {
      if ((access.role == UserRole.pharmacy ||
              access.role == UserRole.veterinarian) &&
          !_isPremiumApprovedOnServer(serverData)) {
        return 'scanner_intro_exhausted';
      }
    }
    if ((access.role == UserRole.pharmacy ||
            access.role == UserRole.veterinarian) &&
        !_isPremiumApprovedOnServer(serverData)) {
      return 'scanner_subscription_required';
    }
    return 'scanner_subscription_required';
  }

  Future<ScanQuotaStatus> getQuotaStatus({
    required String userId,
    required PremiumAccess access,
  }) async {
    if (access.grantsFullPremium) {
      return ScanQuotaStatus.allowed(
        tier: ScanLimitTier.monthly,
        used: 0,
        limit: 9999,
      );
    }

    final doc = await _fetchUserQuotaDoc(userId);
    final data = doc.data() ?? {};
    final quota = _quotaSnapshot(data);

    if (!_canUseAiScannerFromServer(
      access: access,
      serverData: data,
      quota: quota,
    )) {
      return ScanQuotaStatus.blocked(
        tier: ScanLimitTier.subscription,
        used: 0,
        limit: 0,
        blockReasonKey: _blockReasonFromServer(
          access: access,
          serverData: data,
          quota: quota,
        ) ?? 'scanner_subscription_required',
      );
    }

    final counters = _normalizeCountersFromSnapshot(quota);
    final now = DateTime.now();
    final limit = await _resolveMonthlyLimit(
      access,
      quota: quota,
      serverData: data,
    );

    if (limit <= 0) {
      return ScanQuotaStatus.blocked(
        tier: ScanLimitTier.subscription,
        used: counters.scansThisMonth,
        limit: 0,
        blockReasonKey: 'scanner_subscription_required',
      );
    }

    if (_usingIntro(quota: quota, access: access, serverData: data)) {
      if (quota.introScansUsed >= SubscriptionLimits.introAiScansTotal) {
        return ScanQuotaStatus.blocked(
          tier: ScanLimitTier.intro,
          used: quota.introScansUsed,
          limit: SubscriptionLimits.introAiScansTotal,
          blockReasonKey: 'scanner_intro_exhausted',
        );
      }
      return ScanQuotaStatus.allowed(
        tier: ScanLimitTier.intro,
        used: quota.introScansUsed,
        limit: SubscriptionLimits.introAiScansTotal,
      );
    }

    final monthly = _applyMonthlyReset(counters, now);
    if (monthly.scansThisMonth >= limit && quota.bonusRemaining <= 0) {
      return ScanQuotaStatus.blocked(
        tier: ScanLimitTier.monthly,
        used: monthly.scansThisMonth,
        limit: limit,
        blockReasonKey: _monthlyBlockReasonKey(access, serverData: data),
        resetsAt: DateTime(now.year, now.month + 1, 1),
      );
    }

    return ScanQuotaStatus.allowed(
      tier: ScanLimitTier.monthly,
      used: monthly.scansThisMonth,
      limit: limit,
      resetsAt: DateTime(now.year, now.month + 1, 1),
      bonusRemaining: quota.bonusRemaining,
    );
  }

  /// Javno — mjesečni limit pretplate za korisnika.
  Future<int> resolveMonthlyLimitForAccess(PremiumAccess access) {
    return _resolveMonthlyLimit(access);
  }

  /// Veličina paketa za dokup (= pola mjesečnog limita).
  Future<int> resolveTopUpPackSizeForAccess(PremiumAccess access) async {
    final monthly = await _resolveMonthlyLimit(access);
    return PaymentService.topUpPackSizeFromMonthlyLimit(monthly);
  }

  Future<int> _resolveMonthlyLimit(
    PremiumAccess access, {
    _UserQuotaSnapshot? quota,
    Map<String, dynamic>? serverData,
  }) async {
    if (access.user == null && serverData == null) return 0;

    final data = serverData ?? const <String, dynamic>{};
    final snapshot = quota ??
        _UserQuotaSnapshot(
          scansThisMonth: access.user?.introScansUsed ?? 0,
          introScansUsed: access.user?.introScansUsed ?? 0,
          bonusRemaining: 0,
          hasFreeScans: access.user?.hasFreeScans ?? true,
          isTrialUsed: access.user?.isTrialUsed ?? false,
          lastScanReset: null,
        );

    if (snapshot.hasFreeScans &&
        !snapshot.isTrialUsed &&
        snapshot.introScansUsed < SubscriptionLimits.introAiScansTotal &&
        !_hasPaidOrPromoFromServer(access, data)) {
      return SubscriptionLimits.introAiScansTotal - snapshot.introScansUsed;
    }

    final serverApproved = _isPremiumApprovedOnServer(data);
    final serverTier = _resolvedBusinessTier(data);
    final user = access.user;

    if (access.role == UserRole.veterinarian) {
      if (_needsAdminVerification(access.role) && !serverApproved) {
        if (access.isInPromoPeriod) {
          return ScanMarketLimits.businessPromoMonthlyLimit;
        }
        return 0;
      }
      if (serverApproved ||
          _hasPaidOrPromoFromServer(access, data) ||
          access.isInPromoPeriod) {
        final billingCountry = PaymentService.resolveBillingCountryForPricing(
          paymentCountryCode: user?.paymentCountryCode ??
              PaymentService.cachedPaymentCountryCode,
        );
        return PaymentService.resolveVetMonthlyScanCap(
          currencyRegion: resolveCurrencyRegionForUser(
            locale: Locale(user?.languageCode ?? access.languageCode),
            storedRegion: user?.currencyRegion,
            deviceCountryCode: billingCountry,
            paymentCountryCode: user?.paymentCountryCode ??
                PaymentService.cachedPaymentCountryCode,
            role: access.role,
          ),
          languageCode: access.languageCode,
          countryCode: billingCountry,
        );
      }
      return 0;
    }

    if (access.role == UserRole.pharmacy) {
      final tier = serverApproved && serverTier != null
          ? serverTier
          : access.effectiveSubscriptionTier;
      if (SubscriptionLimits.hasBusinessLicense(tier)) {
        final billingCountry = PaymentService.resolveBillingCountryForPricing(
          paymentCountryCode: user?.paymentCountryCode ??
              PaymentService.cachedPaymentCountryCode,
        );
        final region = resolveCurrencyRegionForLocale(
          Locale(user?.languageCode ?? access.languageCode),
          storedRegion: user?.currencyRegion,
          deviceCountryCode: billingCountry,
          paymentCountryCode: resolvePaymentCountryCode(
            fromProfile: user?.paymentCountryCode,
          ),
        );
        return PaymentService.companyMonthlyScanCapForDisplay(
          languageCode: access.languageCode,
          currencyRegion: region,
          countryCode: billingCountry,
        );
      }
      if (access.isPremium || user?.premiumActive == true) {
        final billingCountry = PaymentService.resolveBillingCountryForPricing(
          paymentCountryCode: user?.paymentCountryCode ??
              PaymentService.cachedPaymentCountryCode,
        );
        final region = resolveCurrencyRegionForLocale(
          Locale(user?.languageCode ?? access.languageCode),
          storedRegion: user?.currencyRegion,
          deviceCountryCode: billingCountry,
          paymentCountryCode: resolvePaymentCountryCode(
            fromProfile: user?.paymentCountryCode,
          ),
        );
        return PaymentService.companyMonthlyScanCapForDisplay(
          languageCode: access.languageCode,
          currencyRegion: region,
          countryCode: billingCountry,
        );
      }
      if (access.isInPromoPeriod) {
        return ScanMarketLimits.businessPromoMonthlyLimit;
      }
    }

    return access.monthlyScanLimit();
  }

  String _monthlyBlockReasonKey(
    PremiumAccess access, {
    Map<String, dynamic>? serverData,
  }) {
    final tier = serverData != null &&
            _isPremiumApprovedOnServer(serverData)
        ? _resolvedBusinessTier(serverData)
        : access.effectiveSubscriptionTier;
    if (access.role == UserRole.pharmacy &&
        SubscriptionLimits.hasBusinessLicense(tier)) {
      return 'scanner_limit_monthly_package';
    }
    return 'scanner_limit_monthly';
  }

  Future<ScanQuotaStatus> checkBeforeScan({
    required String userId,
    required PremiumAccess access,
  }) {
    return getQuotaStatus(userId: userId, access: access);
  }

  Future<void> recordScan({
    required String userId,
    required PremiumAccess access,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? {};
      final quota = _quotaSnapshot(data);
      final usingIntro = _usingIntro(
        quota: quota,
        access: access,
        serverData: data,
      );
      var counters = _normalizeCountersFromSnapshot(quota);

      if (usingIntro) {
        transaction.set(
          userRef,
          {'introScansUsed': quota.introScansUsed + 1},
          SetOptions(merge: true),
        );
        return;
      }

      final monthlyLimit = await _resolveMonthlyLimit(
        access,
        quota: quota,
        serverData: data,
      );
      counters = _applyMonthlyReset(counters, now);

      if (counters.scansThisMonth < monthlyLimit) {
        transaction.set(
          userRef,
          {
            'scansThisMonth': counters.scansThisMonth + 1,
            'lastScanReset': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      } else if (quota.bonusRemaining > 0) {
        transaction.set(
          userRef,
          {
            ScanTopUpService.bonusScansField: quota.bonusRemaining - 1,
            'lastScanReset': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  _ScanCounters _normalizeCountersFromSnapshot(_UserQuotaSnapshot quota) {
    return _ScanCounters(
      scansThisMonth: quota.scansThisMonth,
      lastScanReset: quota.lastScanReset,
    );
  }

  _ScanCounters _applyMonthlyReset(_ScanCounters counters, DateTime now) {
    if (!_isSameMonth(counters.lastScanReset, now)) {
      return _ScanCounters(
        scansThisMonth: 0,
        lastScanReset: now,
      );
    }
    return counters;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool _isSameMonth(DateTime? a, DateTime now) {
    if (a == null) return false;
    return a.year == now.year && a.month == now.month;
  }
}

class _ScanCounters {
  final int scansThisMonth;
  final DateTime? lastScanReset;

  const _ScanCounters({
    required this.scansThisMonth,
    this.lastScanReset,
  });
}

class _UserQuotaSnapshot {
  const _UserQuotaSnapshot({
    required this.scansThisMonth,
    required this.introScansUsed,
    required this.bonusRemaining,
    required this.hasFreeScans,
    required this.isTrialUsed,
    required this.lastScanReset,
  });

  final int scansThisMonth;
  final int introScansUsed;
  final int bonusRemaining;
  final bool hasFreeScans;
  final bool isTrialUsed;
  final DateTime? lastScanReset;
}

final scanLimitServiceProvider = Provider<ScanLimitService>(
  (ref) => ScanLimitService(),
);
