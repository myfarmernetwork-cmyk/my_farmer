import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_config.dart';
import '../services/app_config_service.dart';

final appConfigProvider = StreamProvider<AppConfig>((ref) {
  return FirebaseFirestore.instance.doc('config/app').snapshots().map((doc) {
    final config = AppConfig.fromMap(doc.data());
    AppConfigService.instance.applyStreamConfig(config);
    return config;
  });
});

/// Firestore `config/app` — samo besplatni meteo-alarmi u testiranju (farmers).
final closedTestingFreeWeatherAlertsProvider = Provider<bool>((ref) {
  return ref.watch(appConfigProvider).valueOrNull?.closedTestingFreeWeatherAlerts ??
      AppConfigService.instance.closedTestingFreeWeatherAlerts;
});

/// Firestore `config/app` — chat besplatni za sve uloge u testiranju.
final closedTestingFreeChatProvider = Provider<bool>((ref) {
  return ref.watch(appConfigProvider).valueOrNull?.closedTestingFreeChat ??
      AppConfigService.instance.closedTestingFreeChat;
});

/// Firestore `config/app` — AI skener besplatan u testiranju (sve uloge).
final closedTestingFreeAiScannerProvider = Provider<bool>((ref) {
  final config = ref.watch(appConfigProvider).valueOrNull ??
      AppConfigService.instance.config;
  if (config.closedTestingFreeChat && config.closedTestingFreeWeatherAlerts) {
    return true;
  }
  return false;
});

/// Firestore `config/app` — kartoteka pacijenata besplatna za veterinare u testiranju.
final closedTestingFreeVetIntakeProvider = Provider<bool>((ref) {
  final config = ref.watch(appConfigProvider).valueOrNull ??
      AppConfigService.instance.config;
  if (config.closedTestingFreeVetIntake) return true;
  // Testna faza: ako su chat i meteo već besplatni, kartoteka isto (bez cijene).
  if (config.closedTestingFreeChat && config.closedTestingFreeWeatherAlerts) {
    return true;
  }
  return false;
});
