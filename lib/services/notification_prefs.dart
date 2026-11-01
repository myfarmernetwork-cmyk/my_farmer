import 'package:shared_preferences/shared_preferences.dart';

/// Lokalna kopija postavki obavijesti (background handler nema Firestore stream).
class NotificationPrefs {
  static const _quietWhenBackgroundKey = 'quiet_when_background';

  static Future<bool> quietWhenBackground() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_quietWhenBackgroundKey) ?? false;
  }

  static Future<void> setQuietWhenBackground(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quietWhenBackgroundKey, value);
  }
}
