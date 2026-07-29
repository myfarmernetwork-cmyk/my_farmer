import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/revenuecat_config.dart';
import '../models/premium_access.dart';
import '../providers/subscription_provider.dart';
import 'payment_service.dart';
import 'scan_limit_service.dart';
import 'subscription_service.dart';

/// Dokup skenova — samo za pretplaćene korisnike, pola mjesečne alokacije.
class ScanTopUpService {
  ScanTopUpService({
    FirebaseFirestore? firestore,
    SubscriptionService? subscriptionService,
    ScanLimitService? scanLimitService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _subscriptionService = subscriptionService ?? SubscriptionService(),
        _scanLimitService = scanLimitService ?? ScanLimitService();

  static const String bonusScansField = 'bonusScansBalance';

  final FirebaseFirestore _firestore;
  final SubscriptionService _subscriptionService;
  final ScanLimitService _scanLimitService;

  bool canPurchaseTopUp(PremiumAccess access) {
    if (access.user == null) return false;
    return access.hasPaidOrPromoAccess &&
        access.canUse(PremiumFeature.aiScanner);
  }

  Future<int> resolvePackSize(PremiumAccess access) async {
    final monthly =
        await _scanLimitService.resolveMonthlyLimitForAccess(access);
    return PaymentService.topUpPackSizeFromMonthlyLimit(monthly);
  }

  Future<bool> purchaseTopUpPack({
    required String userId,
    required PremiumAccess access,
    required String languageCode,
    String? currencyRegion,
  }) async {
    if (!canPurchaseTopUp(access)) return false;

    final packSize = await resolvePackSize(access);
    if (packSize <= 0) return false;

    final charged = await _chargeTopUp(
      packSize: packSize,
      languageCode: languageCode,
    );
    if (!charged) return false;

    await _creditBonusScans(userId: userId, amount: packSize);
    return true;
  }

  Future<bool> _chargeTopUp({
    required int packSize,
    required String languageCode,
  }) async {
    final eur = PaymentService.scanTopUpPackPriceEur(packSize);

    if (RevenueCatConfig.simulationMode) {
      debugPrint(
        'Scan top-up simulation: +$packSize scans charged at '
        '${eur.toStringAsFixed(2)} EUR '
        '(profit ${(packSize * PaymentService.scanTopUpProfitEur).toStringAsFixed(2)} EUR)',
      );
      return true;
    }

    return _subscriptionService.purchaseConsumableProductId(
      RevenueCatConfig.scanTopUpPack,
    );
  }

  Future<void> _creditBonusScans({
    required String userId,
    required int amount,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final current = _asInt(snapshot.data()?[bonusScansField]);
      transaction.set(
        userRef,
        {bonusScansField: current + amount},
        SetOptions(merge: true),
      );
    });
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

final scanTopUpServiceProvider = Provider<ScanTopUpService>(
  (ref) => ScanTopUpService(
    subscriptionService: ref.read(subscriptionServiceProvider),
    scanLimitService: ref.read(scanLimitServiceProvider),
  ),
);
