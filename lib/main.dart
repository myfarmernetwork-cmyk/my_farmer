import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/locale_settings_provider.dart';
import 'screens/auth_gate.dart';
import 'services/firestore_cache_service.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/subscription_service.dart';
import 'config/beta_config.dart';
import 'config/revenuecat_config.dart';
import 'config/nirs_monitoring_config.dart';
import 'config/plant_scanner_config.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  NotificationService().setNavigatorKey(navigatorKey);

  runApp(
    EasyLocalization(
      supportedLocales: supportedEasyLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useFallbackTranslations: true,
      saveLocale: true,
      child: const ProviderScope(
        child: MyApp(),
      ),
    ),
  );

  // Prvo nacrtaj UI (skini Android splash), tek onda teški init u pozadini.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_completeStartup());
  });
}

Future<void> _completeStartup() async {
  await Future<void>.delayed(const Duration(milliseconds: 400));

  try {
    await NotificationService().initNotifications();
  } catch (e, stack) {
    debugPrint('Notification init skipped: $e\n$stack');
  }

  try {
    RevenueCatConfig.assertProductionBillingReady();
    NirsMonitoringConfig.assertProductionReady();
    PlantScannerConfig.assertProductionReady();

    if (!BetaConfig.closedTestFreePremium) {
      await SubscriptionService()
          .configure()
          .timeout(const Duration(seconds: 12), onTimeout: () {});
      await PaymentService.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    }

    await FirestoreCacheService.clearStaleCacheIfNeeded();
  } catch (e, stack) {
    debugPrint('Billing/services startup issue: $e\n$stack');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'My Farmer',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        primaryColor: Colors.green,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
