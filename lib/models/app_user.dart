import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/subscription_limits.dart';
import 'subscription_tier.dart';

enum UserRole {
  buyer,
  hobbyFarmer,
  professionalFarmer,
  veterinarian,
  pharmacy,
  admin,
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final bool isVerified;
  final bool isPublicProfile;
  final bool isTrialUsed;
  final bool hasFreeScans;
  final String? preferredLanguage;
  final String? deviceId;
  final Timestamp? verifiedAt;
  final Timestamp? promotionalEndsAt;
  final String? subscriptionTier;
  final int introScansUsed;
  final String? favoriteVetId;
  final String? premiumApprovalStatus;
  final String? requestedPremiumTier;
  final String? currencyRegion;
  final String? paymentCountryCode;
  final bool isActive;
  final bool isAdminAccount;
  final bool premiumActive;
  final bool weatherAlertsEnabled;
  final String? status;
  final Timestamp? subscriptionExpiresAt;
  final Timestamp? accountDeletionRequestedAt;
  final Timestamp? accountDeletionScheduledAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.isVerified = true,
    this.isPublicProfile = true,
    this.isTrialUsed = false,
    this.hasFreeScans = true,
    this.preferredLanguage,
    this.deviceId,
    this.verifiedAt,
    this.promotionalEndsAt,
    this.subscriptionTier,
    this.introScansUsed = 0,
    this.favoriteVetId,
    this.premiumApprovalStatus,
    this.requestedPremiumTier,
    this.currencyRegion,
    this.paymentCountryCode,
    this.isActive = true,
    this.isAdminAccount = false,
    this.premiumActive = false,
    this.weatherAlertsEnabled = true,
    this.status,
    this.subscriptionExpiresAt,
    this.accountDeletionRequestedAt,
    this.accountDeletionScheduledAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final roleRaw = readRoleField(data);
    var parsedRole = parseRole(roleRaw);
    final isAdminFlag = data['isAdmin'] as bool? ?? false;
    if (isAdminFlag) {
      parsedRole = UserRole.admin;
    }
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: parsedRole,
      isVerified: data['isVerified'] as bool? ?? _defaultVerified(roleRaw),
      isPublicProfile: data['isPublicProfile'] as bool? ??
          _defaultPublicProfile(roleRaw, data['isVerified']),
      isTrialUsed: data['isTrialUsed'] as bool? ?? false,
      hasFreeScans: data['hasFreeScans'] as bool? ?? true,
      preferredLanguage: data['preferredLanguage'] as String?,
      deviceId: data['deviceId'] as String?,
      verifiedAt: data['verifiedAt'] as Timestamp?,
      promotionalEndsAt: data['promotionalEndsAt'] as Timestamp?,
      subscriptionTier: data['subscriptionTier'] as String?,
      introScansUsed: _asInt(data['introScansUsed']),
      favoriteVetId: data['favoriteVetId'] as String?,
      premiumApprovalStatus: data['premiumApprovalStatus'] as String?,
      requestedPremiumTier: data['requestedPremiumTier'] as String?,
      currencyRegion: data['currencyRegion'] as String?,
      paymentCountryCode: data['paymentCountryCode'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      isAdminAccount: data['isAdmin'] as bool? ?? false,
      premiumActive: data['premiumActive'] as bool? ?? false,
      weatherAlertsEnabled: data['weatherAlertsEnabled'] as bool? ?? true,
      status: data['status'] as String?,
      subscriptionExpiresAt: data['subscriptionExpiresAt'] as Timestamp?,
      accountDeletionRequestedAt:
          data['accountDeletionRequestedAt'] as Timestamp?,
      accountDeletionScheduledAt:
          data['accountDeletionScheduledAt'] as Timestamp?,
    );
  }

  bool get isPendingDeletion =>
      status?.toUpperCase() == 'PENDING_DELETION';

  bool get isPremiumApproved =>
      premiumApprovalStatus?.toUpperCase() == 'APPROVED';

  bool get isPremiumPending =>
      premiumApprovalStatus?.toUpperCase() == 'PENDING';

  SubscriptionTier? get approvedTier {
    if (!isPremiumApproved) return null;
    return SubscriptionTierX.fromFirestore(subscriptionTier);
  }

  SubscriptionTier? get activeTier =>
      SubscriptionTierX.fromFirestore(subscriptionTier);

  bool get hasVetLicense =>
      isPremiumApproved &&
      activeTier == SubscriptionTier.veterinarianLicense;

  bool get hasBusinessLicense =>
      isPremiumApproved &&
      activeTier == SubscriptionTier.pharmacyLicense;

  String get languageCode {
    if (preferredLanguage == null || preferredLanguage!.isEmpty) return 'hr';
    return preferredLanguage!.split('_').first;
  }

  static bool _defaultVerified(dynamic role) => true;

  static bool _defaultPublicProfile(dynamic role, dynamic isVerified) {
    final canonical = normalizeRoleAlias(role?.toString());
    if (canonical == 'veterinarian') return false;
    return true;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static bool _hasText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isNotEmpty && text.toLowerCase() != 'null';
  }

  /// Samo profilna polja — ne čita polje [role] (koristi se za oporavak pogrešnog buyer-a).
  static String? inferRoleFromProfileFields(Map<String, dynamic> data) {
    if (data['isAdmin'] == true) return 'admin';

    if (_hasText(data['companyRegistrationNumber'])) return 'company';

    if (_hasText(data['veterinaryLicense'])) return 'veterinarian';

    if (_hasText(data['farmNumber'])) return 'professional_farmer';

    final tier = data['subscriptionTier']?.toString() ??
        data['requestedPremiumTier']?.toString() ??
        '';
    switch (tier) {
      case 'pharmacy_license':
        return 'pharmacy';
      case 'veterinarian_license':
        return 'veterinarian';
      case 'professional_farmer_premium':
        return 'professional_farmer';
      case 'hobby_farmer_premium':
        return 'hobby_farmer';
    }

    return null;
  }

  static String? _readExplicitRoleField(Map<String, dynamic> data) {
    for (final key in ['role', 'userRole', 'accountType', 'user_type', 'type']) {
      final val = data[key]?.toString().trim();
      if (_hasText(val)) return val;
    }
    return null;
  }

  /// Stvarna uloga — ignorira pogrešno spremljeni buyer ako profil kaže drugačije.
  static String? readRoleField(Map<String, dynamic> data) {
    final explicit = _readExplicitRoleField(data);
    final explicitCanonical = normalizeRoleAlias(explicit);

    if (explicitCanonical.isNotEmpty && explicitCanonical != 'buyer') {
      return explicit;
    }

    final inferred = inferRoleFromProfileFields(data);
    if (inferred != null) return inferred;

    return explicit;
  }

  /// Kanonska uloga spremna za navigaciju i UI.
  static String resolveRoleCanonical(Map<String, dynamic> data) {
    return normalizeRoleAlias(readRoleField(data));
  }

  static String normalizeRoleAlias(String? role) {
    final normalized = role?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return '';
    switch (normalized) {
      case 'veterinar':
      case 'veterinarian':
        return 'veterinarian';
      case 'company':
      case 'firma':
      case 'pharmacy':
        return 'pharmacy';
      case 'hobbyist_farmer':
      case 'hobby_farmer':
      case 'hobi_farmer':
        return 'hobby_farmer';
      case 'pro_farmer':
      case 'professional_farmer':
      case 'farmer':
      case 'services':
        return 'professional_farmer';
      case 'admin':
        return 'admin';
      case 'buyer':
      case 'kupac':
        return 'buyer';
      default:
        return normalized;
    }
  }

  static bool roleNeedsVerification(String? role) {
    final canonical = normalizeRoleAlias(role);
    return canonical == 'veterinarian' || canonical == 'pharmacy';
  }

  static UserRole parseRole(String? role) {
    final canonical = normalizeRoleAlias(role);
    if (canonical.isEmpty) return UserRole.buyer;
    switch (canonical) {
      case 'hobby_farmer':
        return UserRole.hobbyFarmer;
      case 'professional_farmer':
      case 'farmer':
      case 'services':
        return UserRole.professionalFarmer;
      case 'veterinarian':
        return UserRole.veterinarian;
      case 'pharmacy':
        return UserRole.pharmacy;
      case 'admin':
        return UserRole.admin;
      default:
        if (canonical.contains('admin')) return UserRole.admin;
        if (canonical.contains('vet') || canonical.contains('veterin')) {
          return UserRole.veterinarian;
        }
        if (canonical.contains('company') ||
            canonical.contains('pharm') ||
            canonical.contains('firma')) {
          return UserRole.pharmacy;
        }
        return UserRole.buyer;
    }
  }

  static String roleToFirestore(UserRole role) {
    switch (role) {
      case UserRole.buyer:
        return 'buyer';
      case UserRole.hobbyFarmer:
        return 'hobby_farmer';
      case UserRole.professionalFarmer:
        return 'professional_farmer';
      case UserRole.veterinarian:
        return 'veterinarian';
      case UserRole.pharmacy:
        return 'pharmacy';
      case UserRole.admin:
        return 'admin';
    }
  }

  bool get needsAdminVerification =>
      role == UserRole.veterinarian || role == UserRole.pharmacy;

  bool get isInPromotionalPeriod {
    if (promotionalEndsAt == null) return false;
    return DateTime.now().isBefore(promotionalEndsAt!.toDate());
  }

  bool get isFarmerRole =>
      role == UserRole.hobbyFarmer || role == UserRole.professionalFarmer;

  bool get isSellerRole =>
      isFarmerRole ||
      role == UserRole.veterinarian ||
      role == UserRole.pharmacy ||
      role == UserRole.admin;

  int get maxProductSlots => SubscriptionLimits.maxProductSlots(
        role: role,
        tier: approvedTier,
        hasPaidBusiness: hasBusinessLicense,
        hasVetPremium: hasVetLicense,
      );

  bool get isPremiumVeterinarian =>
      role == UserRole.veterinarian && hasVetLicense;

  bool get hasVerifiedVetBadge =>
      isPremiumVeterinarian && isPremiumApproved;

  bool get canOfferServices => role == UserRole.professionalFarmer;

  bool get isAdminUser => role == UserRole.admin || isAdminAccount;

  String get roleFirestore => roleToFirestore(role);
}
