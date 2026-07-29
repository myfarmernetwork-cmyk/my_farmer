import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/subscription_limits.dart';
import '../models/app_user.dart';
import '../models/premium_access.dart';
import '../models/scan_market_limits.dart';
import '../models/scan_quota.dart';
import '../providers/locale_settings_provider.dart';
import 'payment_service.dart';
import 'scan_topup_service.dart';

class ScanLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    if (!access.canUse(PremiumFeature.aiScanner)) {
      final user = access.user;
      String reason = 'scanner_subscription_required';
      if (user != null && !user.hasFreeScans) {
        reason = 'scanner_device_trial_used';
      } else if (user != null && user.isPremiumPending) {
        reason = 'premium_pending_admin_approval';
      }
      return ScanQuotaStatus.blocked(
        tier: ScanLimitTier.subscription,
        used: 0,
        limit: 0,
        blockReasonKey: reason,
      );
    }

    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data() ?? {};
    final counters = _normalizeCounters(data);
    final bonusRemaining = _asInt(data[ScanTopUpService.bonusScansField]);
    final now = DateTime.now();
    final limit = await _resolveMonthlyLimit(access);

    if (limit <= 0) {
      return ScanQuotaStatus.blocked(
        tier: ScanLimitTier.subscription,
        used: counters.scansThisMonth,
        limit: 0,
        blockReasonKey: 'scanner_subscription_required',
      );
    }

    final usingIntro = access.user?.hasFreeScans == true &&
        access.user?.isTrialUsed != true &&
        (access.user?.introScansUsed ?? 0) <
            SubscriptionLimits.introAiScansTotal &&
        !access.hasPaidOrPromoAccess &&
        !(access.user?.needsAdminVerification ?? false);

    if (usingIntro) {
      final used = access.user?.introScansUsed ?? 0;
      if (used >= SubscriptionLimits.introAiScansTotal) {
        return ScanQuotaStatus.blocked(
          tier: ScanLimitTier.intro,
          used: used,
          limit: SubscriptionLimits.introAiScansTotal,
          blockReasonKey: 'scanner_intro_exhausted',
        );
      }
      return ScanQuotaStatus.allowed(
        tier: ScanLimitTier.intro,
        used: used,
        limit: SubscriptionLimits.introAiScansTotal,
      );
    }

    final monthly = _applyMonthlyReset(counters, now);
    if (monthly.scansThisMonth >= limit && bonusRemaining <= 0) {
      return ScanQuotaStatus.blocked(
        tier: ScanLimitTier.monthly,
        used: monthly.scansThisMonth,
        limit: limit,
        blockReasonKey: _monthlyBlockReasonKey(access),
        resetsAt: DateTime(now.year, now.month + 1, 1),
      );
    }

    return ScanQuotaStatus.allowed(
      tier: ScanLimitTier.monthly,
      used: monthly.scansThisMonth,
      limit: limit,
      resetsAt: DateTime(now.year, now.month + 1, 1),
      bonusRemaining: bonusRemaining,
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

  Future<int> _resolveMonthlyLimit(PremiumAccess access) async {
    if (access.user == null) return 0;

    if (access.user!.hasFreeScans == true &&
        access.user!.isTrialUsed != true &&
        (access.user!.introScansUsed) <
            SubscriptionLimits.introAiScansTotal &&
        !access.hasPaidOrPromoAccess &&
        !(access.user!.needsAdminVerification)) {
      return SubscriptionLimits.introAiScansTotal -
          access.user!.introScansUsed;
    }

    if (access.role == UserRole.veterinarian) {
      if (access.user!.needsAdminVerification &&
          !access.user!.isPremiumApproved) {
        if (access.isInPromoPeriod) {
          return ScanMarketLimits.businessPromoMonthlyLimit;
        }
        return 0;
      }
      if (access.hasPaidOrPromoAccess || access.isInPromoPeriod) {
        final user = access.user!;
        final billingCountry = PaymentService.resolveBillingCountryForPricing(
          paymentCountryCode: user.paymentCountryCode ??
              PaymentService.cachedPaymentCountryCode,
        );
        return PaymentService.resolveVetMonthlyScanCap(
          currencyRegion: resolveCurrencyRegionForUser(
            locale: Locale(user.languageCode),
            storedRegion: user.currencyRegion,
            deviceCountryCode: billingCountry,
            paymentCountryCode: user.paymentCountryCode ??
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
      final tier = access.effectiveSubscriptionTier;
      if (SubscriptionLimits.hasBusinessLicense(tier)) {
        final user = access.user!;
        final billingCountry = PaymentService.resolveBillingCountryForPricing(
          paymentCountryCode: user.paymentCountryCode ??
              PaymentService.cachedPaymentCountryCode,
        );
        final region = resolveCurrencyRegionForLocale(
          Locale(user.languageCode),
          storedRegion: user.currencyRegion,
          deviceCountryCode: billingCountry,
          paymentCountryCode: resolvePaymentCountryCode(
            fromProfile: user.paymentCountryCode,
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

  String _monthlyBlockReasonKey(PremiumAccess access) {
    if (access.role == UserRole.pharmacy &&
        access.hasPharmacyLicense &&
        SubscriptionLimits.hasBusinessLicense(access.effectiveSubscriptionTier)) {
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

    final usingIntro = access.user?.hasFreeScans == true &&
        access.user?.isTrialUsed != true &&
        (access.user?.introScansUsed ?? 0) <
            SubscriptionLimits.introAiScansTotal &&
        !access.hasPaidOrPromoAccess &&
        !(access.user?.needsAdminVerification ?? false);

    final monthlyLimit = usingIntro
        ? 0
        : await _resolveMonthlyLimit(access);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? {};
      var counters = _normalizeCounters(data);

      if (usingIntro) {
        final current = _asInt(data['introScansUsed']);
        transaction.set(
          userRef,
          {'introScansUsed': current + 1},
          SetOptions(merge: true),
        );
        return;
      }

      counters = _applyMonthlyReset(counters, now);
      final bonus = _asInt(data[ScanTopUpService.bonusScansField]);

      if (counters.scansThisMonth < monthlyLimit) {
        transaction.set(
          userRef,
          {
            'scansThisMonth': counters.scansThisMonth + 1,
            'lastScanReset': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      } else if (bonus > 0) {
        transaction.set(
          userRef,
          {
            ScanTopUpService.bonusScansField: bonus - 1,
            'lastScanReset': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  _ScanCounters _normalizeCounters(Map<String, dynamic> data) {
    return _ScanCounters(
      scansThisMonth: _asInt(data['scansThisMonth']),
      lastScanReset: _asDateTime(data['lastScanReset']),
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

final scanLimitServiceProvider = Provider<ScanLimitService>(
  (ref) => ScanLimitService(),
);
