/// Uloge korisnika i poslovna pravila pretplate — službeni model.
library;

export 'app_user.dart' show UserRole, AppUser;
export '../config/subscription_limits.dart';

import 'app_user.dart';
import '../config/subscription_limits.dart';

class UserRoleRules {
  UserRoleRules._();

  /// Jedinstvena Premium pretplata veterinara — 9,99 €/mj.
  static bool hasVetPremium(AppUser user) =>
      user.role == UserRole.veterinarian &&
      SubscriptionLimits.vetHasPatientRecords(
        role: user.role,
        tier: user.approvedTier,
        isPremiumApproved: user.isPremiumApproved,
      );

  /// Kupac ne smije prodavati artikle.
  static bool canSell(AppUser user) =>
      user.role != UserRole.buyer &&
      SubscriptionLimits.canSellOnMarketplace(user.role);

  /// Medicinska apoteka / Moja pijaca — veterinar smije prodavati suplemente.
  static bool canUseVetMarketplace(AppUser user) =>
      user.role == UserRole.veterinarian;

  static int vetMarketplaceLimit(AppUser user) =>
      SubscriptionLimits.maxProductSlots(
        role: user.role,
        tier: user.approvedTier,
        hasVetPremium: hasVetPremium(user),
      );

  /// Izbornik životinja / kućnih ljubimaca (kupac, hobi, pro — ne veterinar).
  static bool canUseAnimalsMenu(AppUser user) =>
      user.role != UserRole.veterinarian &&
      SubscriptionLimits.maxAnimals(
        role: user.role,
        tier: user.approvedTier,
        hasPaidPremium: _hasPaidPremium(user),
      ) >
      0;

  /// Kartoteka pacijenata — Premium Veterinar 9,99 €.
  static bool canUsePatientRecords(AppUser user) => hasVetPremium(user);

  static bool isPatientRecordsLocked(AppUser user) =>
      user.role == UserRole.veterinarian && !canUsePatientRecords(user);

  /// Moji ljubimci — do 10 privatnih kućnih ljubimaca uz istu Premium pretplatu.
  static bool canUsePrivatePets(AppUser user) => hasVetPremium(user);

  static bool isPrivatePetsLocked(AppUser user) =>
      user.role == UserRole.veterinarian && !canUsePrivatePets(user);

  static int maxPrivatePets(AppUser user) =>
      hasVetPremium(user) ? SubscriptionLimits.vetPremiumMaxPrivatePets : 0;

  /// Besplatni veterinar vidljiv samo ručnom pretragom imena.
  static bool vetFindableByNameOnly(AppUser vet) =>
      vet.role == UserRole.veterinarian && vet.isVerified;

  /// Premium veterinar u radaru prve pomoći.
  static bool vetInFirstAidRadar(AppUser vet) =>
      SubscriptionLimits.vetAppearsInProximityRadar(
        role: vet.role,
        tier: vet.approvedTier,
        isPremiumApproved: vet.isPremiumApproved,
      );

  static int productLimit(AppUser user) => user.maxProductSlots;

  static bool canReserveUpcoming(AppUser user) =>
      SubscriptionLimits.canReserveUpcomingInCart(
        role: user.role,
        tier: user.approvedTier,
        hasPaidPremium: _hasPaidPremium(user),
      );

  static bool _hasPaidPremium(AppUser user) {
    if (user.needsAdminVerification) {
      return user.isPremiumApproved && user.subscriptionTier != null;
    }
    return user.subscriptionTier != null;
  }
}
