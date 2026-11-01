import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_version.dart';
import 'payment_service.dart';

/// Bilježi odakle je korisnik došao (zemlja, jezik, verzija) za admin statistiku.
class UserAttributionService {
  UserAttributionService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static String? _lastSessionUid;
  static DateTime? _lastSessionAt;
  static const _sessionThrottle = Duration(hours: 6);

  static String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }

  /// Prije [registerWithProfile] — best-effort GPS / locale uređaja.
  static Future<Map<String, dynamic>> captureForSignup({
    required String localeStorageKey,
  }) async {
    await PaymentService.resolveDeviceCountry();
    final deviceCountry = _normalizeCountry(
      PaymentService.cachedGpsVerifiedCountryCode ??
          PaymentService.cachedDeviceCountryCode,
    );
    final ipCountry = _normalizeCountry(PaymentService.cachedIpCountryCode);

    return {
      if (deviceCountry != null) 'signupCountryCode': deviceCountry,
      if (ipCountry != null) 'signupIpCountryCode': ipCountry,
      'signupLocale': localeStorageKey,
      'signupPlatform': _platform,
      'signupAppVersion': AppVersion.label,
      'signupSource': _platform == 'android' ? 'google_play' : 'app_store',
      'signupRecordedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Svaki ulazak u app (throttled) — ažurira lastSeen* i dopuni signup* starijim profilima.
  Future<void> recordSession({
    required String uid,
    String? localeStorageKey,
  }) async {
    if (_shouldSkipSession(uid)) return;

    try {
      await PaymentService.resolveDeviceCountry();
      final deviceCountry = _normalizeCountry(
        PaymentService.cachedGpsVerifiedCountryCode ??
            PaymentService.cachedDeviceCountryCode,
      );
      final ipCountry = _normalizeCountry(PaymentService.cachedIpCountryCode);

      final snap = await _firestore.collection('users').doc(uid).get();
      final existing = snap.data() ?? {};
      final locale = localeStorageKey?.trim().isNotEmpty == true
          ? localeStorageKey!.trim()
          : existing['preferredLanguage']?.toString().trim() ?? '';

      final updates = <String, dynamic>{
        if (deviceCountry != null) 'lastSeenCountryCode': deviceCountry,
        if (ipCountry != null) 'lastSeenIpCountryCode': ipCountry,
        if (locale.isNotEmpty) 'lastSeenLocale': locale,
        'lastSeenAppVersion': AppVersion.label,
        'lastSeenPlatform': _platform,
      };

      if (existing['signupCountryCode'] == null && deviceCountry != null) {
        updates['signupCountryCode'] = deviceCountry;
        if (ipCountry != null) updates['signupIpCountryCode'] = ipCountry;
        if (locale.isNotEmpty) updates['signupLocale'] = locale;
        updates['signupPlatform'] = _platform;
        updates['signupAppVersion'] = AppVersion.label;
        updates['signupSource'] = _platform == 'android' ? 'google_play' : 'app_store';
        updates['signupBackfilledAt'] = FieldValue.serverTimestamp();
        if (existing['signupRecordedAt'] == null) {
          updates['signupRecordedAt'] = FieldValue.serverTimestamp();
        }
      }

      await _firestore.collection('users').doc(uid).set(
            updates,
            SetOptions(merge: true),
          );

      _lastSessionUid = uid;
      _lastSessionAt = DateTime.now();
    } catch (_) {
      // Best-effort — ne blokira app.
    }
  }

  bool _shouldSkipSession(String uid) {
    if (_lastSessionUid != uid) return false;
    final at = _lastSessionAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < _sessionThrottle;
  }

  static String? _normalizeCountry(String? raw) {
    if (raw == null) return null;
    final code = raw.trim().toUpperCase();
    if (code.length != 2) return null;
    return code;
  }
}
