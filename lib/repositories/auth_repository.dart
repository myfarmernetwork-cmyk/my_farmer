import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../services/device_lock_service.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  factory AuthRepository() => instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceLockService _deviceLockService = DeviceLockService();

  String? _lastBlockMessage;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _accountWatchSub;
  AppUser? _lastSyncedUser;

  static const accountBlockedMessageHr =
      'Vaš račun je blokiran od strane administratora. Kontaktirajte podršku.';
  static const accountBlockedMessageDe =
      'Ihr Konto wurde vom Administrator gesperrt. Bitte kontaktieren Sie den Support.';
  static const accountDeletionPendingMessageHr =
      'Vaš račun je označen za brisanje. Prijava više nije moguća.';
  static const accountDeletionPendingMessageDe =
      'Ihr Konto ist zur Löschung vorgemerkt. Eine Anmeldung ist nicht mehr möglich.';

  String? consumeAccountBlockMessage() {
    final message = _lastBlockMessage;
    _lastBlockMessage = null;
    return message;
  }

  bool _isUserActive(Map<String, dynamic> data) {
    return data['isActive'] as bool? ?? true;
  }

  String _blockedAccountMessage(Map<String, dynamic> data) {
    if ((data['status'] as String?)?.toUpperCase() == 'PENDING_DELETION') {
      return accountDeletionPendingMessageHr;
    }
    return accountBlockedMessageHr;
  }

  Future<void> _handleBlockedAccount([Map<String, dynamic>? data]) async {
    _lastBlockMessage ??=
        data != null ? _blockedAccountMessage(data) : accountBlockedMessageHr;
    stopWatchingAccount();
    await _auth.signOut();
  }

  /// Provjera pri pokretanju aplikacije — povuci ulogu s servera i odjavi blokirane.
  Future<void> ensureActiveSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      clearSessionCache();
      return;
    }

    await syncRoleFromServer();
  }

  /// Prati promjenu isActive dok je korisnik prijavljen (admin blokada uživo).
  void watchAccountBlocked(String uid) {
    _accountWatchSub?.cancel();
    _accountWatchSub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data != null && !_isUserActive(data)) {
        _handleBlockedAccount(data);
      }
    });
  }

  void stopWatchingAccount() {
    _accountWatchSub?.cancel();
    _accountWatchSub = null;
  }

  /// Potpuno resetira lokalnu sesiju (poziva se pri odjavi).
  void clearSessionCache() {
    stopWatchingAccount();
    _lastBlockMessage = null;
    _lastSyncedUser = null;
  }

  AppUser? get lastSyncedUser => _lastSyncedUser;

  void publishSyncedUser(AppUser user) {
    _lastSyncedUser = user;
  }

  /// Prisilno povlači profil iz Firestore-a (server-first kad je potrebno).
  Future<AppUser?> syncRoleFromServer() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      clearSessionCache();
      return null;
    }

    var data = await _pullUserDocumentFromFirestore(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      forceServer: true,
    );

    if (!_isUserActive(data)) {
      await _handleBlockedAccount();
      clearSessionCache();
      return null;
    }

    data = await _sanitizeUserDocument(
      uid: firebaseUser.uid,
      data: data,
      email: firebaseUser.email ?? '',
    );

    data = await _restoreRoleIfCorrupted(data: data);

    final appUser = AppUser.fromMap(firebaseUser.uid, data);
    publishSyncedUser(appUser);
    return appUser;
  }

  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        clearSessionCache();
        return null;
      }

      var data = await _pullUserDocumentFromFirestore(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        forceServer: true,
      );

      if (!_isUserActive(data)) {
        await _handleBlockedAccount();
        clearSessionCache();
        return null;
      }

      data = await _sanitizeUserDocument(
        uid: firebaseUser.uid,
        data: data,
        email: firebaseUser.email ?? '',
      );

      data = await _restoreRoleIfCorrupted(data: data);

      final appUser = AppUser.fromMap(firebaseUser.uid, data);
      publishSyncedUser(appUser);
      return appUser;
    });
  }

  Future<Map<String, dynamic>> _pullUserDocumentFromFirestore({
    required String uid,
    required String email,
    bool forceServer = false,
  }) async {
    final doc = await _firestore.collection('users').doc(uid).get(
          GetOptions(
            source: forceServer ? Source.server : Source.serverAndCache,
          ),
        );

    if (!doc.exists || doc.data() == null) {
      final retry = await _fetchUserDoc(uid);
      if (retry.exists && retry.data() != null) {
        return _repairUserDocument(
          uid: uid,
          email: email,
          data: Map<String, dynamic>.from(retry.data()!),
          allowRoleMutation: false,
        );
      }
      throw AuthException(
        'Korisnički profil nije pronađen u bazi. Kontaktirajte podršku.',
      );
    }

    return _repairUserDocument(
      uid: uid,
      email: email,
      data: Map<String, dynamic>.from(doc.data()!),
      allowRoleMutation: false,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserDoc(
    String uid,
  ) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final doc = await _firestore.collection('users').doc(uid).get(
            const GetOptions(source: Source.server),
          );
      if (doc.exists) return doc;
      await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
    }
    return _firestore.collection('users').doc(uid).get(
          const GetOptions(source: Source.server),
        );
  }

  Map<String, dynamic> _roleSpecificFields({
    required String canonicalRole,
    String extraInfo = '',
    String? veterinaryLicense,
    String? companyRegistrationNumber,
  }) {
    final fields = <String, dynamic>{};

    switch (canonicalRole) {
      case 'veterinarian':
        fields['veterinaryLicense'] =
            (veterinaryLicense ?? extraInfo).trim();
        break;
      case 'pharmacy':
        final reg = (companyRegistrationNumber ?? extraInfo).trim();
        fields['companyRegistrationNumber'] = reg;
        fields['extraInfo'] = reg;
        break;
      case 'hobby_farmer':
      case 'professional_farmer':
        if (extraInfo.trim().isNotEmpty) {
          fields['farmNumber'] = extraInfo.trim();
          fields['extraInfo'] = extraInfo.trim();
        }
        break;
      default:
        if (extraInfo.trim().isNotEmpty) {
          fields['extraInfo'] = extraInfo.trim();
        }
    }

    return fields;
  }

  Future<Map<String, dynamic>> _repairUserDocument({
    required String uid,
    required String email,
    required Map<String, dynamic> data,
    bool allowRoleMutation = false,
  }) async {
    final updates = <String, dynamic>{};
    final rawRole = AppUser.readRoleField(data);
    final canonicalRole = AppUser.normalizeRoleAlias(rawRole);

    // Samo normaliziraj alias (company→pharmacy). NIKAD ne prepisuj na buyer pri loginu!
    if (allowRoleMutation &&
        rawRole != null &&
        rawRole.isNotEmpty &&
        canonicalRole.isNotEmpty &&
        canonicalRole != rawRole.trim().toLowerCase()) {
      updates['role'] = canonicalRole;
    }

    final effectiveRole = updates['role']?.toString() ??
        (canonicalRole.isNotEmpty ? canonicalRole : 'buyer');

    final status = data['status']?.toString().trim().toUpperCase() ?? '';
    if (status == 'PENDING' &&
        (data['premiumApprovalStatus'] == null ||
            data['premiumApprovalStatus'].toString().isEmpty)) {
      updates['status'] = 'ACTIVE';
      updates['isVerified'] = true;
    } else if (status.isEmpty) {
      updates['status'] = 'ACTIVE';
    }

    if (data['isVerified'] == false &&
        (data['premiumApprovalStatus'] == null ||
            data['premiumApprovalStatus'].toString().isEmpty)) {
      updates['isVerified'] = true;
    }

    if (!data.containsKey('isPublicProfile')) {
      updates['isPublicProfile'] = effectiveRole != 'veterinarian';
    }

    final emailValue = data['email']?.toString().trim() ?? '';
    if (emailValue.isEmpty && email.isNotEmpty) {
      updates['email'] = email.trim();
    }

    final nameValue = data['name']?.toString().trim() ?? '';
    if (nameValue.isEmpty) {
      updates['name'] = _nameFromEmail(email);
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).set(
            updates,
            SetOptions(merge: true),
          );
      data.addAll(updates);
    }

    // Osiguraj da vraćeni map sadrži ispravnu ulogu u memoriji.
    final resolved = AppUser.resolveRoleCanonical(data);
    if (resolved.isNotEmpty) {
      data['role'] = resolved;
    }

    return data;
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first.trim();
    return local.isEmpty ? 'Korisnik' : local;
  }

  /// Popravlja oštećene dokumente (npr. email spremljen kao ime polja umjesto email).
  Future<Map<String, dynamic>> _sanitizeUserDocument({
    required String uid,
    required Map<String, dynamic> data,
    required String email,
  }) async {
    final updates = <String, dynamic>{};
    final sanitized = Map<String, dynamic>.from(data);

    final emailValue = sanitized['email']?.toString().trim() ?? '';
    if (emailValue.isEmpty) {
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final val = entry.value?.toString().trim() ?? '';
        if (key.contains('@') && val.contains('@')) {
          sanitized['email'] = val;
          updates['email'] = val;
          break;
        }
      }
      if (!sanitized.containsKey('email') || sanitized['email'].toString().isEmpty) {
        if (email.trim().isNotEmpty) {
          sanitized['email'] = email.trim();
          updates['email'] = email.trim();
        }
      }
    }

    final nameValue = sanitized['name']?.toString().trim() ?? '';
    if (nameValue.isEmpty) {
      final effectiveEmail =
          sanitized['email']?.toString().trim() ?? email.trim();
      if (effectiveEmail.isNotEmpty) {
        final name = _nameFromEmail(effectiveEmail);
        sanitized['name'] = name;
        updates['name'] = name;
      }
    }

    // Osiguraj da se role iz Firestore-a nikad ne izgubi.
    final rawRole = data['role']?.toString().trim();
    if (rawRole != null && rawRole.isNotEmpty) {
      sanitized['role'] = rawRole;
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).set(
            updates,
            SetOptions(merge: true),
          );
    }

    return sanitized;
  }

  /// Ako je uloga pogrešno prepisana na buyer, koristi inferenciju samo u memoriji.
  /// Trajna promjena uloge u Firestoreu dopuštena je samo administratoru / Cloud Functions.
  Future<Map<String, dynamic>> _restoreRoleIfCorrupted({
    required Map<String, dynamic> data,
  }) async {
    final stored = data['role']?.toString().trim().toLowerCase() ?? '';
    final resolved = AppUser.resolveRoleCanonical(data);
    if (resolved.isNotEmpty &&
        resolved != stored &&
        (stored.isEmpty || stored == 'buyer')) {
      return {...data, 'role': resolved};
    }

    return data;
  }

  Future<AppUser> registerWithProfile({
    required String email,
    required String password,
    required String role,
    required String name,
    String address = '',
    String phone = '',
    String extraInfo = '',
    String? veterinaryLicense,
    String? companyRegistrationNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;
    if (user == null) {
      throw AuthException('Registracija nije uspjela.');
    }

    final deviceResult = await _deviceLockService.evaluateDevice();
    final trialLocked = deviceResult.shouldLockFreeScans;
    final canonicalRole = AppUser.normalizeRoleAlias(role);

    final payload = <String, dynamic>{
      'role': canonicalRole,
      'name': name.trim(),
      'email': email.trim(),
      'address': address.trim(),
      'phone': phone.trim(),
      'status': 'ACTIVE',
      'isAvailable': true,
      'offersPickup': true,
      'offersDelivery': false,
      'preferredLanguage': 'hr_HR',
      'isVerified': true,
      'isPublicProfile': canonicalRole != 'veterinarian',
      'isActive': true,
      'isTrialUsed': trialLocked,
      'hasFreeScans': !trialLocked,
      if (deviceResult.deviceId != null) 'deviceId': deviceResult.deviceId,
      'introScansUsed': 0,
      'scansThisMonth': 0,
      'lastScanReset': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'privacyPolicyAcceptedAt': FieldValue.serverTimestamp(),
      ..._roleSpecificFields(
        canonicalRole: canonicalRole,
        extraInfo: extraInfo,
        veterinaryLicense: veterinaryLicense,
        companyRegistrationNumber: companyRegistrationNumber,
      ),
    };

    await _firestore.collection('users').doc(user.uid).set(payload);

    if (deviceResult.deviceId != null && !trialLocked) {
      try {
        await _deviceLockService.registerDevice(
          deviceId: deviceResult.deviceId!,
          userId: user.uid,
          email: email.trim(),
        );
      } catch (_) {
        // Registracija profila uspjela — zaključavanje uređaja nije kritično.
      }
    }

    return AppUser.fromMap(user.uid, payload);
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;
    if (user == null) {
      throw AuthException('Prijava nije uspjela.');
    }

    clearSessionCache();

    var data = await _pullUserDocumentFromFirestore(
      uid: user.uid,
      email: user.email ?? email.trim(),
      forceServer: true,
    );

    if (!_isUserActive(data)) {
      _lastBlockMessage = _blockedAccountMessage(data);
      await _auth.signOut();
      clearSessionCache();
      throw AuthException(accountBlockedMessageHr);
    }

    data = await _sanitizeUserDocument(
      uid: user.uid,
      data: data,
      email: user.email ?? email.trim(),
    );

    data = await _restoreRoleIfCorrupted(data: data);

    final appUser = AppUser.fromMap(user.uid, data);
    publishSyncedUser(appUser);
    return appUser;
  }

  Future<void> logout() async {
    clearSessionCache();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
