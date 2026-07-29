import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import 'firestore_cache_service.dart';
import 'notification_service.dart';

/// Servis za autentifikaciju — delegira na [AuthRepository].
class AuthService {
  AuthService({AuthRepository? repository})
      : _repository = repository ?? AuthRepository.instance;

  final AuthRepository _repository;

  Stream<AppUser?> authStateChanges() => _repository.authStateChanges();

  /// Prijava + trenutno povlačenje uloge s Firestore servera i objava u sesiju.
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    _repository.clearSessionCache();

    await _repository.login(
      email: email,
      password: password,
    );

    final synced = await _repository.syncRoleFromServer();
    if (synced != null) {
      _repository.watchAccountBlocked(synced.uid);
      return synced;
    }

    throw AuthException('Korisnički profil nije pronađen.');
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
  }) =>
      _repository.registerWithProfile(
        email: email,
        password: password,
        role: role,
        name: name,
        address: address,
        phone: phone,
        extraInfo: extraInfo,
        veterinaryLicense: veterinaryLicense,
        companyRegistrationNumber: companyRegistrationNumber,
      );

  Future<void> logout() => logoutAndClearCache();

  /// Odjavi korisnika i potpuno očisti lokalnu predmemoriju sesije.
  Future<void> logoutAndClearCache() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await NotificationService().clearTokenForUser(uid);
    }
    _repository.clearSessionCache();
    await _repository.logout();
    await FirestoreCacheService.forceClear();
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _repository.sendPasswordResetEmail(email);

  String? consumeAccountBlockMessage() =>
      _repository.consumeAccountBlockMessage();

  /// Pri pokretanju — prisilna provjera aktivnosti i uloge s Firestore servera.
  Future<void> ensureActiveSession() => _repository.ensureActiveSession();

  /// Prisilno povlači točnu ulogu iz Firestore-a (server-first).
  Future<AppUser?> syncRoleFromServer() => _repository.syncRoleFromServer();

  void watchAccountBlocked(String uid) =>
      _repository.watchAccountBlocked(uid);

  void stopWatchingAccount() => _repository.stopWatchingAccount();

  void clearSessionCache() => _repository.clearSessionCache();

  AppUser? get lastSyncedUser => _repository.lastSyncedUser;
}
