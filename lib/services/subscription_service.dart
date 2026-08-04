import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/revenuecat_config.dart';
import '../models/app_user.dart';
import '../models/subscription_tier.dart';
import 'payment_service.dart';
import 'subscription_tier_sync.dart';

class SubscriptionService {
  final StreamController<bool> _premiumController =
      StreamController<bool>.broadcast();

  bool _configured = false;
  bool _lastPremium = false;
  bool _lastIsTrial = false;

  Stream<bool> get premiumStatusStream => _premiumController.stream;

  bool get lastKnownIsPremium => _lastPremium;
  bool get lastKnownIsTrial => _lastIsTrial;

  Future<void> configure() async {
    if (_configured || !RevenueCatConfig.isConfigured) return;

    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    }

    final apiKey = Platform.isAndroid
        ? RevenueCatConfig.androidApiKey
        : RevenueCatConfig.iosApiKey;

    if (apiKey.isEmpty) return;

    try {
      await Purchases.configure(PurchasesConfiguration(apiKey)).timeout(
        const Duration(seconds: 12),
      );
    } on TimeoutException {
      debugPrint('Purchases.configure timed out');
      return;
    }

    Purchases.addCustomerInfoUpdateListener(_handleCustomerInfo);

    _configured = true;
    try {
      await refreshPremiumStatus().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      debugPrint('refreshPremiumStatus timed out');
    }
    try {
      await syncPaymentStoreCountry().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      debugPrint('syncPaymentStoreCountry timed out');
    }
  }

  /// Država Play/App Store računa — odakle se stvarno plaća pretplata.
  Future<String?> syncPaymentStoreCountry({String? userId}) async {
    if (!_configured) return PaymentService.cachedPaymentCountryCode;

    try {
      final storefront = await Purchases.storefront;
      final code = storefront?.countryCode.trim().toUpperCase();
      if (code == null || code.isEmpty) {
        return PaymentService.cachedPaymentCountryCode;
      }

      PaymentService.cachePaymentCountryCode(code);

      if (userId != null && userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set(
          {'paymentCountryCode': code},
          SetOptions(merge: true),
        );
      }
      return code;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('syncPaymentStoreCountry: $e');
      }
      return PaymentService.cachedPaymentCountryCode;
    }
  }

  Future<void> logIn(String appUserId) async {
    if (!_configured) await configure();
    if (!_configured) return;

    await Purchases.logIn(appUserId);
    await refreshPremiumStatus();
    await syncPaymentStoreCountry(userId: appUserId);
  }

  Future<void> logOut() async {
    if (!_configured) return;

    await Purchases.logOut();
    _emitPremium(false);
  }

  Future<bool> refreshPremiumStatus() async {
    if (!_configured) {
      _emitPremium(false);
      return false;
    }

    final info = await Purchases.getCustomerInfo();
    return _handleCustomerInfo(info);
  }

  Future<Offerings?> getOfferings() async {
    if (!_configured) await configure();
    if (!_configured) return null;

    return Purchases.getOfferings();
  }

  Future<bool> purchasePackage(Package package) async {
    if (!_configured) return false;

    try {
      final customerInfo = await Purchases.purchasePackage(package);
      await syncPaymentStoreCountry(
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
      return _handleCustomerInfo(customerInfo);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  /// Kupnja po Google Play Product ID-u.
  /// U [RevenueCatConfig.simulationMode] ne zove Play Store — simulira premium uz kanonsku cijenu.
  Future<bool> purchaseProductId(String productId) async {
    if (RevenueCatConfig.simulationMode) {
      if (kReleaseMode) {
        throw StateError(
          'Simulacija pretplata nije dozvoljena u release buildu.',
        );
      }
      final cents = RevenueCatConfig.monthlyPriceCentsForProductId(productId);
      if (cents != null && cents > 0) {
        debugPrint(
          'Subscription simulation: $productId charged at ${cents / 100} EUR',
        );
      }
      _emitPremium(true);
      return true;
    }

    if (!_configured) await configure();
    if (!_configured) return false;

    final offerings = await getOfferings();
    final package = _findPackageByProductId(offerings, productId);
    if (package == null) {
      throw StateError(
        'Product "$productId" nije pronađen u RevenueCat offerings. '
        'Provjeri Play Console i RevenueCat dashboard.',
      );
    }

    return purchasePackage(package);
  }

  /// Jednokratna (consumable) kupnja — ne mijenja premium status.
  Future<bool> purchaseConsumableProductId(String productId) async {
    if (RevenueCatConfig.simulationMode) {
      if (kReleaseMode) {
        throw StateError(
          'Simulacija consumable kupnje nije dozvoljena u release buildu.',
        );
      }
      debugPrint('Consumable simulation: $productId');
      return true;
    }

    if (!_configured) await configure();
    if (!_configured) return false;

    final offerings = await getOfferings();
    final package = _findPackageByProductId(offerings, productId);
    if (package == null) {
      throw StateError(
        'Consumable "$productId" nije pronađen u RevenueCat offerings.',
      );
    }

    try {
      await Purchases.purchasePackage(package);
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  Package? _findPackageByProductId(Offerings? offerings, String productId) {
    if (offerings == null) return null;

    for (final offering in offerings.all.values) {
      for (final package in offering.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          return package;
        }
      }
    }

    final current = offerings.current;
    if (current != null) {
      for (final package in current.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          return package;
        }
      }
    }

    return null;
  }

  Future<bool> restorePurchases() async {
    if (!_configured) return false;

    final info = await Purchases.restorePurchases();
    await syncPaymentStoreCountry(
      userId: FirebaseAuth.instance.currentUser?.uid,
    );
    return _handleCustomerInfo(info);
  }

  /// Otvara Play Store / App Store ekran za upravljanje pretplatom.
  Future<bool> showManageSubscriptions() async {
    return _openStoreSubscriptionFallback();
  }

  Future<bool> _openStoreSubscriptionFallback() async {
    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse(
            'https://play.google.com/store/account/subscriptions?package=com.myfarmer.network',
          );

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('subscription fallback url: $e');
      }
      return false;
    }
  }

  bool _handleCustomerInfo(CustomerInfo info) {
    final entitlement =
        info.entitlements.all[RevenueCatConfig.entitlementId];
    final isPremium = entitlement?.isActive ?? false;
    final isTrial =
        isPremium && entitlement?.periodType == PeriodType.trial;
    _lastIsTrial = isTrial;
    _emitPremium(isPremium, expirationDate: entitlement?.expirationDate);
    return isPremium;
  }

  void _emitPremium(bool value, {String? expirationDate}) {
    _lastPremium = value;
    if (!value) {
      _lastIsTrial = false;
    }
    if (!_premiumController.isClosed) {
      _premiumController.add(value);
    }
    unawaited(_syncPremiumActiveToFirestore(
      value,
      expirationDate: expirationDate,
    ));
  }

  Future<DateTime?> getActiveSubscriptionExpiry() async {
    if (!_configured) return null;

    try {
      final info = await Purchases.getCustomerInfo();
      final entitlement =
          info.entitlements.all[RevenueCatConfig.entitlementId];
      if (entitlement?.isActive != true) return null;
      final raw = entitlement?.expirationDate;
      if (raw == null || raw.trim().isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getActiveSubscriptionExpiry: $e');
      }
      return null;
    }
  }

  Future<void> _syncPremiumActiveToFirestore(
    bool isPremium, {
    String? expirationDate,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    Timestamp? expiresAt;
    if (isPremium && expirationDate != null && expirationDate.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(expirationDate);
      if (parsed != null) {
        expiresAt = Timestamp.fromDate(parsed.toUtc());
      }
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};
      final existingTier = data['subscriptionTier']?.toString().trim() ?? '';

      final updates = <String, dynamic>{
        'premiumActive': isPremium,
        'premiumActiveUpdatedAt': FieldValue.serverTimestamp(),
        if (isPremium) 'weatherAlertsEnabled': true,
        if (expiresAt != null)
          'subscriptionExpiresAt': expiresAt
        else if (!isPremium)
          'subscriptionExpiresAt': FieldValue.delete(),
      };

      if (isPremium && existingTier.isEmpty) {
        final role = AppUser.parseRole(AppUser.resolveRoleCanonical(data));
        final inferred = tierForRole(role);
        if (role == UserRole.buyer ||
            role == UserRole.hobbyFarmer ||
            role == UserRole.professionalFarmer) {
          updates['subscriptionTier'] = inferred.firestoreValue;
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
            updates,
            SetOptions(merge: true),
          );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('syncPremiumActive: $e');
      }
    }
  }

  void dispose() {
    _premiumController.close();
  }
}
