import 'package:shared_preferences/shared_preferences.dart';

/// GPS dozvola pri prvom ulasku u aplikaciju nakon prijave.
class LocationInstallPrefs {
  LocationInstallPrefs._();

  static const _completedKey = 'location_install_completed_v1';
  static const _countryKey = 'location_install_gps_country_v1';

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }

  static Future<void> saveGpsCountry(String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countryKey, countryCode.trim().toUpperCase());
  }

  static Future<String?> loadGpsCountry() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_countryKey);
    if (code == null || code.length != 2) return null;
    return code.toUpperCase();
  }
}
