import 'package:shared_preferences/shared_preferences.dart';

import '../features/forum/models/forum_category.dart';

/// Lokalno vrijeme zadnjeg pregleda forum kategorije po korisniku.
class ForumSeenPrefs {
  static String _key(String uid, ForumCategory category) =>
      'forum_seen_${uid}_${category.firestoreValue}';

  static Future<DateTime?> seenAt(String uid, ForumCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_key(uid, category));
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<Map<ForumCategory, DateTime>> allSeenAt(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <ForumCategory, DateTime>{};
    for (final category in ForumCategory.values) {
      final millis = prefs.getInt(_key(uid, category));
      if (millis != null) {
        result[category] = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }
    return result;
  }

  static Future<void> markSeen(String uid, ForumCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _key(uid, category),
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
