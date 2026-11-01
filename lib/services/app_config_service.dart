import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_config.dart';

/// Učitava `config/app` (cache za weather provider pri cold startu).
class AppConfigService {
  AppConfigService._();

  static final AppConfigService instance = AppConfigService._();

  AppConfig _config = const AppConfig();
  bool _loaded = false;

  AppConfig get config => _config;

  bool get closedTestingFreeWeatherAlerts =>
      _config.closedTestingFreeWeatherAlerts;

  bool get closedTestingFreeChat => _config.closedTestingFreeChat;

  bool get closedTestingFreeVetIntake => _config.closedTestingFreeVetIntake;

  Future<void> ensureLoaded() async {
    if (_loaded) return;

    try {
      final doc = await FirebaseFirestore.instance
          .doc('config/app')
          .get(const GetOptions(source: Source.serverAndCache));
      _config = AppConfig.fromMap(doc.data());
    } catch (_) {
      _config = const AppConfig();
    }
    _loaded = true;
  }

  void applyStreamConfig(AppConfig next) {
    _config = next;
    _loaded = true;
  }
}
