import 'package:shared_preferences/shared_preferences.dart';

class FarmerHelperPrefs {
  FarmerHelperPrefs._();

  static const _welcomeSeenKey = 'farmer_welcome_seen_v1';

  static Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeSeenKey) ?? false;
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
  }
}
