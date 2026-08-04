import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Briše zastarjeli Firestore cache na uređaju nakon ažuriranja auth logike.
class FirestoreCacheService {
  FirestoreCacheService._();

  static const _versionKey = 'firestore_role_cache_version';
  static const _currentVersion = 4;

  /// Pozovi jednom pri pokretanju — preskače ako je cache već očišćen.
  static Future<void> clearStaleCacheIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_versionKey) ?? 0;
    if (stored >= _currentVersion) return;

    await _clearFirestorePersistence();
    await prefs.setInt(_versionKey, _currentVersion);
  }

  /// Prisilno očisti Firestore cache (npr. pri odjavi).
  static Future<void> forceClear() async {
    await _clearFirestorePersistence();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_versionKey, _currentVersion);
  }

  static Future<void> _clearFirestorePersistence() async {
    try {
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.clearPersistence();
    } catch (_) {
      // Cache možda nije inicijaliziran — nije kritično.
    }
  }
}
