import 'package:shared_preferences/shared_preferences.dart';

class CompanyCatalogPrefs {
  CompanyCatalogPrefs._();

  static const _welcomeSeenKey = 'company_catalog_welcome_seen_v1';
  static const _spotlightSeenKey = 'company_catalog_spotlight_seen_v1';
  static const _autoOpenedKey = 'company_catalog_auto_opened_v1';

  static Future<bool> hasAutoOpenedCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoOpenedKey) ?? false;
  }

  static Future<void> markAutoOpenedCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoOpenedKey, true);
  }

  static Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeSeenKey) ?? false;
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
  }

  static Future<bool> hasSeenSpotlight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_spotlightSeenKey) ?? false;
  }

  static Future<void> markSpotlightSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_spotlightSeenKey, true);
  }
}
