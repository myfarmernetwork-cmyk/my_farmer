import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/beta_config.dart';
import '../models/app_user.dart';
import '../models/premium_access.dart';
import '../models/subscription_tier.dart';
import 'admin_role_preview_provider.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';
import '../services/payment_service.dart';
import '../services/subscription_service.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(service.dispose);
  return service;
});

AppUser? _userFromFirestoreSnapshot({
  required DocumentSnapshot<Map<String, dynamic>> doc,
  required String uid,
  required AppUser? trustedUser,
  required AuthRepository repo,
}) {
  if (!doc.exists || doc.data() == null) {
    return trustedUser;
  }

  // Zastarjeli lokalni cache ne smije prepisati server potvrđenu ulogu.
  if (doc.metadata.isFromCache &&
      trustedUser != null &&
      trustedUser.uid == uid) {
    return trustedUser;
  }

  final data = Map<String, dynamic>.from(doc.data()!);
  final resolved = AppUser.resolveRoleCanonical(data);
  if (resolved.isNotEmpty) {
    data['role'] = resolved;
  }
  final user = AppUser.fromMap(uid, data);
  repo.publishSyncedUser(user);
  return user;
}

/// Live Firestore profil — server-first, zatim stream (cache se ignorira).
final userDocProvider = StreamProvider<AppUser?>((ref) async* {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) {
    yield null;
    return;
  }

  final repo = ref.read(authRepositoryProvider);
  final serverUser = await repo.syncRoleFromServer();
  if (serverUser != null) {
    yield serverUser;
  }

  final trusted = repo.lastSyncedUser;

  yield* FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .where((doc) {
        final hasTrusted = trusted?.uid == authUser.uid;
        if (hasTrusted && doc.metadata.isFromCache) return false;
        return doc.exists && doc.data() != null;
      })
      .map(
        (doc) => _userFromFirestoreSnapshot(
          doc: doc,
          uid: authUser.uid,
          trustedUser: repo.lastSyncedUser ?? trusted ?? authUser,
          repo: repo,
        ),
      )
      .where((user) => user != null)
      .cast<AppUser>();
});

final isPremiumProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(subscriptionServiceProvider);
  await service.configure();
  yield service.lastKnownIsPremium;
  yield* service.premiumStatusStream;
});

final isTrialProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(subscriptionServiceProvider);
  await service.configure();
  yield service.lastKnownIsTrial;
  yield* service.premiumStatusStream.map((_) => service.lastKnownIsTrial);
});

/// Admin ili zatvoreno testiranje — bez paywalla i cijena u UI-u.
final grantsFullPremiumProvider = Provider<bool>((ref) {
  return ref.watch(adminPremiumBypassProvider) ||
      BetaConfig.closedTestFreePremium;
});

final closedTestFreePremiumProvider = Provider<bool>(
  (ref) => BetaConfig.closedTestFreePremium,
);

/// Admin — besplatan pristup svim premium opcijama (bez paywalla).
final adminPremiumBypassProvider = Provider<bool>((ref) {
  final user = ref.watch(userDocProvider).valueOrNull ??
      ref.watch(authStateProvider).valueOrNull;
  final firestoreRole = ref.watch(firestoreUserRoleProvider).valueOrNull;
  return PaymentService.hasAdminPremiumBypass(
    user,
    resolvedFirestoreRole: firestoreRole,
  );
});

final premiumAccessProvider = Provider<PremiumAccess>((ref) {
  final user = ref.watch(userDocProvider).valueOrNull ??
      ref.watch(authStateProvider).valueOrNull;
  final isPremiumFromStore = ref.watch(isPremiumProvider).value ?? false;
  final isAdminBypass = ref.watch(adminPremiumBypassProvider);
  final closedTestFreePremium = BetaConfig.closedTestFreePremium;
  final isPremium =
      isPremiumFromStore || isAdminBypass || closedTestFreePremium;
  final effectiveRole = ref.watch(effectiveUserRoleProvider);

  return PremiumAccess(
    isPremium: isPremium,
    isAdminBypass: isAdminBypass,
    closedTestFreePremium: closedTestFreePremium,
    effectiveRole: effectiveRole,
    user: user,
    languageCode: user?.languageCode ?? 'hr',
  );
});

/// Već plaćena pretplata ili čeka admin aktivaciju — ne otvaraj paywall ponovo.
bool userAlreadySubscribed({
  required AppUser? user,
  required bool storePremium,
}) {
  if (BetaConfig.closedTestFreePremium) return true;
  if (storePremium) return true;
  if (user == null) return false;
  if (user.isPremiumPending) return true;
  if (user.subscriptionTier != null && user.subscriptionTier!.trim().isNotEmpty) {
    return true;
  }
  if (user.requestedPremiumTier != null &&
      user.requestedPremiumTier!.trim().isNotEmpty) {
    return true;
  }
  return false;
}

bool readUserAlreadySubscribed(WidgetRef ref) {
  final user = ref.read(userDocProvider).valueOrNull ??
      ref.read(authStateProvider).valueOrNull;
  final storePremium = ref.read(isPremiumProvider).value ?? false;
  return userAlreadySubscribed(user: user, storePremium: storePremium);
}

bool _isPremiumFarmerTier(SubscriptionTier? tier) {
  return tier == SubscriptionTier.hobbyFarmerPremium ||
      tier == SubscriptionTier.professionalFarmerPremium;
}

/// Ista logika kao [functions/weather_alerts.js] — meteo-alarmi za farmere.
bool hasFarmerWeatherAlertsAccess({
  required AppUser? user,
  required bool storePremium,
  required bool isAdminBypass,
}) {
  if (isAdminBypass) return true;
  if (user == null || !user.isFarmerRole) return false;
  if (!user.weatherAlertsEnabled) return false;

  if (user.premiumActive || storePremium) return true;
  if (user.isInPromotionalPeriod) return true;

  final tier = user.activeTier;
  if (!_isPremiumFarmerTier(tier)) return false;

  if (user.isPremiumApproved) return true;

  // Stariji profili: tier postoji, approval polje još nije bilo u upotrebi.
  final rawTier = user.subscriptionTier?.trim() ?? '';
  return rawTier.isNotEmpty && _isPremiumFarmerTier(
        SubscriptionTierX.fromFirestore(rawTier),
      );
}

/// Meteo-alarmi — farmer s aktivnom pretplatom (Firestore + Play Store).
final weatherPremiumAccessProvider = Provider<bool>((ref) {
  if (ref.watch(adminPremiumBypassProvider)) return true;
  if (BetaConfig.closedTestFreePremium) return true;

  final user = ref.watch(userDocProvider).valueOrNull ??
      ref.watch(authStateProvider).valueOrNull;
  final storePremium = ref.watch(isPremiumProvider).valueOrNull ??
      user?.premiumActive ??
      false;

  return hasFarmerWeatherAlertsAccess(
    user: user,
    storePremium: storePremium,
    isAdminBypass: false,
  );
});
