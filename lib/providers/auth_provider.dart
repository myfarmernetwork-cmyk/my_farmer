import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'subscription_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(repository: ref.watch(authRepositoryProvider));
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
});

/// Očisti sve auth-related providere nakon odjave ili prije prisilne sinkronizacije.
void invalidateAuthSessionCache(WidgetRef ref) {
  ref.read(authRepositoryProvider).clearSessionCache();
  ref.invalidate(authStateProvider);
  ref.invalidate(userDocProvider);
  ref.invalidate(firestoreUserRoleProvider);
  ref.invalidate(adminPremiumBypassProvider);
  ref.invalidate(isPremiumProvider);
  ref.invalidate(isTrialProvider);
}

/// Prisilno osvježi ulogu iz Firestore-a i invalidira predmemoriju providera.
Future<AppUser?> refreshAuthSessionFromFirestore(WidgetRef ref) async {
  final user = await ref.read(authServiceProvider).syncRoleFromServer();
  if (user != null) {
    ref.read(authRepositoryProvider).publishSyncedUser(user);
  }
  ref.invalidate(userDocProvider);
  ref.invalidate(firestoreUserRoleProvider);
  ref.invalidate(adminPremiumBypassProvider);
  return user;
}

/// Uživo uloga iz Firestore users/{uid} — server-first, cache se ignorira.
final firestoreUserRoleProvider = StreamProvider<String?>((ref) async* {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) {
    yield null;
    return;
  }

  final repo = ref.read(authRepositoryProvider);
  final serverUser = await repo.syncRoleFromServer();
  if (serverUser != null) {
    yield serverUser.roleFirestore;
  }

  final trustedRole = repo.lastSyncedUser?.roleFirestore;

  yield* FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .where((doc) {
        if (trustedRole != null && doc.metadata.isFromCache) return false;
        return doc.exists && doc.data() != null;
      })
      .map((doc) {
        final data = Map<String, dynamic>.from(doc.data()!);
        final resolved = AppUser.resolveRoleCanonical(data);
        if (resolved.isNotEmpty) {
          data['role'] = resolved;
        }
        if (!doc.metadata.isFromCache) {
          repo.publishSyncedUser(AppUser.fromMap(authUser.uid, data));
        }
        return resolved.isEmpty ? null : resolved;
      })
      .where((role) => role != null)
      .cast<String>();
});
