import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_event_key.dart';

/// Trajno pamti koje su push obavijesti prikazane ili odbačene s trake telefona.
class NotificationDismissalStore {
  NotificationDismissalStore._();

  static const _maxKeys = 600;
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static String? _uidOrNull() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  static String _dismissedKey(String uid) => 'notif_dismissed_$uid';
  static String _trayShownKey(String uid) => 'notif_tray_shown_$uid';
  static String _idMapKey(String uid) => 'notif_id_map_$uid';

  static Future<Set<String>> _readSet(String storageKey) async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getStringList(storageKey);
    if (raw == null) return <String>{};
    return raw.toSet();
  }

  static Future<void> _writeSet(String storageKey, Set<String> values) async {
    final prefs = await _ensurePrefs();
    final trimmed = values.length <= _maxKeys
        ? values
        : values.skip(values.length - _maxKeys).toSet();
    await prefs.setStringList(storageKey, trimmed.toList());
  }

  static Future<Map<String, String>> _readIdMap(String uid) async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_idMapKey(uid));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeIdMap(String uid, Map<String, String> map) async {
    final prefs = await _ensurePrefs();
    if (map.length > _maxKeys) {
      final keys = map.keys.toList()..sort();
      final overflow = keys.length - _maxKeys;
      for (var i = 0; i < overflow; i++) {
        map.remove(keys[i]);
      }
    }
    await prefs.setString(_idMapKey(uid), jsonEncode(map));
  }

  /// Ne prikazuj u system trayu (obrisano ili već prikazano).
  static Future<bool> isBlocked(String? uid, String eventKey) async {
    if (uid == null || eventKey.isEmpty) return false;
    final dismissed = await _readSet(_dismissedKey(uid));
    if (dismissed.contains(eventKey)) return true;
    final shown = await _readSet(_trayShownKey(uid));
    return shown.contains(eventKey);
  }

  static Future<bool> isBlockedForCurrentUser(String eventKey) async {
    return isBlocked(_uidOrNull(), eventKey);
  }

  static Future<void> markTrayShown(String? uid, String eventKey) async {
    if (uid == null || eventKey.isEmpty) return;
    final shown = await _readSet(_trayShownKey(uid));
    shown.add(eventKey);
    await _writeSet(_trayShownKey(uid), shown);
  }

  static Future<void> markTrayShownForCurrentUser(String eventKey) async {
    await markTrayShown(_uidOrNull(), eventKey);
  }

  static Future<void> markDismissed(String? uid, String eventKey) async {
    if (uid == null || eventKey.isEmpty) return;
    final dismissed = await _readSet(_dismissedKey(uid));
    dismissed.add(eventKey);
    await _writeSet(_dismissedKey(uid), dismissed);

    final shown = await _readSet(_trayShownKey(uid));
    if (shown.remove(eventKey)) {
      await _writeSet(_trayShownKey(uid), shown);
    }
  }

  static Future<void> markDismissedForCurrentUser(String eventKey) async {
    await markDismissed(_uidOrNull(), eventKey);
  }

  static Future<void> linkNotificationId(
    String? uid,
    int notificationId,
    String eventKey,
  ) async {
    if (uid == null || eventKey.isEmpty) return;
    final map = await _readIdMap(uid);
    map[notificationId.toString()] = eventKey;
    await _writeIdMap(uid, map);
  }

  static Future<void> markDismissedByNotificationId(int notificationId) async {
    final uid = _uidOrNull();
    if (uid == null) return;
    final map = await _readIdMap(uid);
    final eventKey = map[notificationId.toString()];
    if (eventKey == null || eventKey.isEmpty) return;
    await markDismissed(uid, eventKey);
  }

  /// Kad obavijest više nije aktivna u trayu, smatraj je odbačenom.
  static Future<void> markMissingActiveAsDismissed(Set<int> activeIds) async {
    final uid = _uidOrNull();
    if (uid == null) return;

    final map = await _readIdMap(uid);
    if (map.isEmpty) return;

    for (final entry in map.entries) {
      final id = int.tryParse(entry.key);
      if (id == null) continue;
      if (activeIds.contains(id)) continue;
      await markDismissed(uid, entry.value);
    }
  }

  static Future<void> recordRemoteMessage(Map<String, dynamic> data) async {
    final eventKey = NotificationEventKey.fromData(data);
    if (eventKey == null) return;
    await markTrayShownForCurrentUser(eventKey);
  }
}
