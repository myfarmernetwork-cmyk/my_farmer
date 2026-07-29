import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import 'upcoming_product_helper.dart';

/// Globalna pravila za Pomoćnik / Showcase vodič — tvrtke ga nikad ne vide.
class FarmerGuideAccess {
  FarmerGuideAccess._();

  static bool isCompanyAccount({
    String? role,
    UserRole? parsedRole,
    Map<String, dynamic>? userData,
  }) {
    if (parsedRole == UserRole.pharmacy) return true;
    if (UpcomingProductHelper.isCompanyRole(role)) return true;
    if (userData == null) return false;

    final canonical = AppUser.resolveRoleCanonical(userData);
    if (UpcomingProductHelper.isCompanyRole(canonical)) return true;

    final inferred = AppUser.inferRoleFromProfileFields(userData);
    if (UpcomingProductHelper.isCompanyRole(inferred)) return true;

    final reg = userData['companyRegistrationNumber']?.toString().trim() ?? '';
    return reg.isNotEmpty && reg.toLowerCase() != 'null';
  }

  static bool isGuideEnabled({
    String? role,
    UserRole? parsedRole,
    Map<String, dynamic>? userData,
  }) {
    if (isCompanyAccount(
      role: role,
      parsedRole: parsedRole,
      userData: userData,
    )) {
      return false;
    }

    final effectiveRole = userData != null
        ? AppUser.resolveRoleCanonical(userData)
        : AppUser.normalizeRoleAlias(role);

    return effectiveRole == 'buyer' ||
        effectiveRole == 'hobby_farmer' ||
        effectiveRole == 'professional_farmer' ||
        effectiveRole == 'farmer';
  }

  static bool isGuideEnabledForRef(WidgetRef ref) {
    final role = ref.watch(firestoreUserRoleProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final parsedRole = authUser?.role ??
        (role != null && role.isNotEmpty ? AppUser.parseRole(role) : null);
    return isGuideEnabled(role: role, parsedRole: parsedRole);
  }

  static bool isGuideEnabledForContainer(ProviderContainer container) {
    final role = container.read(firestoreUserRoleProvider).valueOrNull;
    final authUser = container.read(authStateProvider).valueOrNull;
    final parsedRole = authUser?.role ??
        (role != null && role.isNotEmpty ? AppUser.parseRole(role) : null);
    return isGuideEnabled(role: role, parsedRole: parsedRole);
  }
}
