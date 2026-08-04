import '../../models/app_user.dart';

/// Tab layout for public seller profiles (all roles that expose a storefront).
///
/// Tab bodies render only the active tab and use [StorefrontProductGrid].
/// Do not use [TabBarView], [NestedScrollView], or shrink-wrapped [GridView].
class StorefrontTabConfig {
  const StorefrontTabConfig({
    required this.showServicesTab,
    required this.tabCount,
    required this.canonicalRole,
  });

  final bool showServicesTab;
  final int tabCount;
  final String canonicalRole;

  factory StorefrontTabConfig.fromRole(String? role) {
    final canonical = AppUser.normalizeRoleAlias(role);
    return StorefrontTabConfig._fromCanonical(canonical);
  }

  factory StorefrontTabConfig.fromSellerData(Map<String, dynamic> farmer) {
    return StorefrontTabConfig._fromCanonical(
      AppUser.resolveRoleCanonical(farmer),
    );
  }

  factory StorefrontTabConfig._fromCanonical(String canonical) {
    final showServices = canonical == 'professional_farmer';
    return StorefrontTabConfig(
      showServicesTab: showServices,
      tabCount: (showServices ? 2 : 1) + 1,
      canonicalRole: canonical,
    );
  }

  bool get isPublicSellerRole {
    switch (canonicalRole) {
      case 'hobby_farmer':
      case 'professional_farmer':
      case 'pharmacy':
      case 'veterinarian':
        return true;
      default:
        return false;
    }
  }
}
