class UpcomingProductHelper {
  UpcomingProductHelper._();

  static const String harvestMode = 'harvest';
  static const String deliveryMode = 'delivery';

  static const int farmerDefaultDays = 7;
  static const int farmerMaxDays = 7;
  static const int companyDefaultDays = 30;
  static const int companyMaxDays = 90;

  static bool isCompanyRole(String? role) {
    final normalized = role?.toLowerCase().trim() ?? '';
    return normalized == 'pharmacy' ||
        normalized == 'firma' ||
        normalized == 'company';
  }

  static bool canUseUpcoming({
    required String? role,
    required bool isPremium,
  }) {
    if (role == 'hobby_farmer') return false;
    if (!isPremium) return false;
    if (isCompanyRole(role)) return true;

    final normalized = role?.toLowerCase().trim() ?? '';
    return normalized == 'professional_farmer' ||
        normalized == 'farmer' ||
        normalized == 'services';
  }

  static String normalizeMode(String? mode) {
    return mode == deliveryMode ? deliveryMode : harvestMode;
  }

  static String modeForRole(String? role) {
    return isCompanyRole(role) ? deliveryMode : harvestMode;
  }

  static int defaultLeadDays(String? role) {
    return isCompanyRole(role) ? companyDefaultDays : farmerDefaultDays;
  }

  static int maxLeadDaysForRole(String? role) {
    return isCompanyRole(role) ? companyMaxDays : farmerMaxDays;
  }

  static int maxLeadDaysForMode(String mode) {
    return mode == deliveryMode ? companyMaxDays : farmerMaxDays;
  }

  static bool isDeliveryMode(String? mode) => normalizeMode(mode) == deliveryMode;
}
