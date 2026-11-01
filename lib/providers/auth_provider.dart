import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'admin_role_preview_provider.dart';
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

/// UID trenutno prijavljenog korisnika — provider se osvježava pri login/logout.
final currentAuthUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

/// Očisti sve auth-related providere nakon odjave ili prije prisilne sinkronizacije.
void invalidateAuthSessionCache(WidgetRef ref) {
  ref.read(authRepositoryProvider).clearSessionCache();
  unawaited(ref.read(adminRolePreviewProvider.notifier).clearOnLogout());
  ref.invalidate(authStateProvider);
  ref.invalidate(userDocProvider);
  ref.invalidate(firestoreUserRoleProvider);
  ref.invalidate(adminRolePreviewProvider);
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

/// Uživo uloga iz Firestore users/{uid} — s retry-em i cache fallbackom.
final firestoreUserRoleProvider = StreamProvider<String?>((ref) async* {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) {
    yield null;
    return;
  }

  final repo = ref.read(authRepositoryProvider);
  final cachedRole = authUser.roleFirestore;
  if (cachedRole.isNotEmpty) {
    yield cachedRole;
  }

  try {
    final serverUser = await repo.syncRoleFromServer();
    if (serverUser != null && serverUser.roleFirestore.isNotEmpty) {
      yield serverUser.roleFirestore;
    }
  } on FirebaseException catch (e) {
    if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
      final fallbackRole =
          repo.lastSyncedUser?.roleFirestore ?? cachedRole;
      if (fallbackRole.isNotEmpty) {
        yield fallbackRole;
      } else {
        rethrow;
      }
    } else {
      rethrow;
    }
  } catch (_) {
    final fallbackRole = repo.lastSyncedUser?.roleFirestore ?? cachedRole;
    if (fallbackRole.isNotEmpty) {
      yield fallbackRole;
      return;
    }
    rethrow;
  }

  yield* FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .where((doc) => doc.exists && doc.data() != null)
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
