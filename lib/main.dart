import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/locale_settings_provider.dart';
import 'repositories/auth_repository.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/firestore_cache_service.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/subscription_service.dart';
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
  await NotificationService().initNotifications();
  RevenueCatConfig.assertProductionBillingReady();
  NirsMonitoringConfig.assertProductionReady();
  PlantScannerConfig.assertProductionReady();
  await SubscriptionService().configure();
  await PaymentService.initialize();

  // Motorola/telefon drži stari Firestore cache — Studio pri flutter run uvijek instalira iznova.
  await FirestoreCacheService.clearStaleCacheIfNeeded();

  // Prisilna sinkronizacija uloge iz Firestore-a pri cold startu (dijeljeni singleton).
  if (FirebaseAuth.instance.currentUser != null) {
    await AuthService(repository: AuthRepository.instance).syncRoleFromServer();
  }

  runApp(
    EasyLocalization(
      // hr, sr, de, zh, bs + regional variants — uklj. Locale('bs') → assets/translations/bs.json
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