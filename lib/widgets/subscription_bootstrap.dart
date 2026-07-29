import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/locale_settings_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/payment_service.dart';

class SubscriptionBootstrap extends ConsumerStatefulWidget {
  final String userId;
  final Widget child;

  const SubscriptionBootstrap({
    super.key,
    required this.userId,
    required this.child,
  });

  @override
  ConsumerState<SubscriptionBootstrap> createState() =>
      _SubscriptionBootstrapState();
}

class _SubscriptionBootstrapState extends ConsumerState<SubscriptionBootstrap> {
  @override
  void initState() {
    super.initState();
    _syncSubscription();
  }

  @override
  void didUpdateWidget(SubscriptionBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _syncSubscription();
    }
  }

  Future<void> _syncSubscription() async {
    final service = ref.read(subscriptionServiceProvider);
    await service.configure();
    await service.logIn(widget.userId);
    final paymentCountry =
        await service.syncPaymentStoreCountry(userId: widget.userId);
    await _refreshCurrencyRegionAfterStoreSync(paymentCountry);
  }

  /// Kad GPS nije dostupan, Play/App Store država određuje cijenu — osvježi profil.
  Future<void> _refreshCurrencyRegionAfterStoreSync(String? paymentCountry) async {
    if (PaymentService.hasGpsVerifiedLocation) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final data = doc.data();
    if (data == null) return;

    final option =
        AppLocaleOption.fromStorageKey(data['preferredLanguage'] as String?);
    final locale = option?.locale;
    if (locale == null) return;

    final role = AppUser.parseRole(data['role']?.toString());
    final storedRegion = data['currencyRegion'] as String?;
    final region = resolveCurrencyRegionForUser(
      locale: locale,
      storedRegion: storedRegion,
      paymentCountryCode: paymentCountry ?? data['paymentCountryCode'] as String?,
      role: role,
    );

    ref.read(currencyRegionProvider.notifier).state = region;
    if (storedRegion != region) {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set(
        {'currencyRegion': region},
        SetOptions(merge: true),
      );
    }
  }

  @override
  void dispose() {
    ref.read(subscriptionServiceProvider).logOut();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
