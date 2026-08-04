import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Updates Firestore when the user is in the app (`isOnline`, `lastActiveAt`).
class UserPresenceService {
  UserPresenceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Timer? _heartbeat;
  String? _uid;
  bool _foreground = false;

  static const _heartbeatInterval = Duration(seconds: 60);

  void start() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _uid = uid;
    _foreground = true;
    unawaited(_touch(online: true));

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      if (_foreground) {
        unawaited(_touch(online: true));
      }
    });
  }

  void onForeground() {
    _foreground = true;
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _uid = uid;
      unawaited(_touch(online: true));
    }
  }

  void onBackground() {
    _foreground = false;
    unawaited(_touch(online: false));
  }

  void stop() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _foreground = false;
    unawaited(_touch(online: false));
    _uid = null;
  }

  Future<void> _touch({required bool online}) async {
    final uid = _uid ?? _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).set(
        {
          'isOnline': online,
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Presence is best-effort — do not block the UI.
    }
  }
}

final userPresenceServiceProvider = Provider<UserPresenceService>((ref) {
  final service = UserPresenceService();
  ref.onDispose(service.stop);
  return service;
});
