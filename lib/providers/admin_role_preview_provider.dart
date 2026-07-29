import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'auth_provider.dart';
import 'subscription_provider.dart';

const _prefsKey = 'admin_preview_role';
const defaultAdminPreviewRole = 'professional_farmer';

/// Uloga koju admin pregledava u aplikaciji (Firestore kanonski string).
class AdminRolePreviewNotifier extends StateNotifier<String> {
  AdminRolePreviewNotifier() : super(defaultAdminPreviewRole) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null && stored.isNotEmpty) {
      state = AppUser.normalizeRoleAlias(stored);
    }
  }

  Future<void> setPreviewRole(String firestoreRole) async {
    final canonical = AppUser.normalizeRoleAlias(firestoreRole);
    state = canonical.isEmpty ? defaultAdminPreviewRole : canonical;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state);
  }
}

final adminRolePreviewProvider =
    StateNotifierProvider<AdminRolePreviewNotifier, String>((ref) {
  return AdminRolePreviewNotifier();
});

/// Stvarna uloga iz Firestore-a (bez admin pregleda).
final realFirestoreRoleProvider = Provider<String>((ref) {
  return ref.watch(firestoreUserRoleProvider).valueOrNull ?? 'buyer';
});

/// Uloga koju UI koristi — admin vidi odabranu preview ulogu.
final effectiveFirestoreRoleProvider = Provider<String>((ref) {
  final isAdmin = ref.watch(adminPremiumBypassProvider);
  if (!isAdmin) {
    return ref.watch(realFirestoreRoleProvider);
  }
  return ref.watch(adminRolePreviewProvider);
});

final effectiveUserRoleProvider = Provider<UserRole>((ref) {
  return AppUser.parseRole(ref.watch(effectiveFirestoreRoleProvider));
});

String adminPreviewRoleLabel(String firestoreRole) {
  switch (AppUser.normalizeRoleAlias(firestoreRole)) {
    case 'buyer':
      return 'Kupac';
    case 'hobby_farmer':
      return 'Hobi Farmer';
    case 'professional_farmer':
      return 'Pro Farmer';
    case 'veterinarian':
      return 'Veterinar';
    case 'pharmacy':
      return 'Firma / Apoteka';
    case 'admin':
      return 'Admin';
    default:
      return firestoreRole;
  }
}

const adminPreviewRoleOptions = [
  ('buyer', 'Kupac'),
  ('hobby_farmer', 'Hobi Farmer'),
  ('professional_farmer', 'Pro Farmer'),
  ('veterinarian', 'Veterinar'),
  ('pharmacy', 'Firma / Apoteka'),
];
