import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/subscription_tier.dart';

/// Admin prikaz pretplate (Firestore + admin grant; Play se synca u premiumActive).
class AdminSubscriptionSummary {
  AdminSubscriptionSummary._();

  static String format(Map<String, dynamic> data) {
    final tierRaw = data['subscriptionTier']?.toString().trim() ?? '';
    final tier = SubscriptionTierX.fromFirestore(tierRaw);
    final tierLabel = _tierLabel(tier, tierRaw);

    final premiumActive = data['premiumActive'] == true;
    final approval =
        data['premiumApprovalStatus']?.toString().trim().toUpperCase() ?? '';
    final grantedBy = data['premiumGrantedBy']?.toString().trim() ?? '';
    final expires = _asDate(data['subscriptionExpiresAt']);
    final promoEnds = _asDate(data['promotionalEndsAt']);
    final now = DateTime.now();

    if (grantedBy == 'admin') {
      if (expires != null && expires.isBefore(now)) {
        return 'Admin Premium — isteklo ${ _fmt(expires)} · $tierLabel';
      }
      if (expires != null) {
        return 'Admin Premium — aktivno do ${_fmt(expires)} · $tierLabel';
      }
      return 'Admin Premium — aktivno (bez roka) · $tierLabel';
    }

    if (approval == 'PENDING') {
      final req = data['requestedPremiumTier']?.toString() ?? tierRaw;
      return 'Na čekanju odobrenja · traži: ${_tierLabel(SubscriptionTierX.fromFirestore(req), req)}';
    }

    if (approval == 'REJECTED') {
      return 'Premium odbijen';
    }

    if (premiumActive) {
      if (expires != null && expires.isBefore(now)) {
        return 'Play/Firestore — isteklo ${_fmt(expires)} · $tierLabel';
      }
      if (expires != null) {
        return 'Aktivna pretplata do ${_fmt(expires)} · $tierLabel';
      }
      return 'Aktivna pretplata · $tierLabel';
    }

    if (promoEnds != null && promoEnds.isAfter(now)) {
      return 'Promo period do ${_fmt(promoEnds)} · $tierLabel';
    }

    if (tierRaw.isNotEmpty && approval == 'APPROVED') {
      return 'Licenca odobrena (bez aktivne Play sync) · $tierLabel';
    }

    if (tierRaw.isNotEmpty) {
      return 'Tier u bazi: $tierLabel · nije aktivno (premiumActive: ne)';
    }

    return 'Bez Premium pretplate';
  }

  static bool hasAdminGrant(Map<String, dynamic> data) {
    return data['premiumGrantedBy']?.toString() == 'admin';
  }

  static String _tierLabel(SubscriptionTier? tier, String raw) {
    switch (tier) {
      case SubscriptionTier.buyerPremium:
        return 'Kupac Premium';
      case SubscriptionTier.hobbyFarmerPremium:
        return 'Hobi Premium';
      case SubscriptionTier.professionalFarmerPremium:
        return 'Pro Premium';
      case SubscriptionTier.veterinarianLicense:
        return 'Veterinar licenca';
      case SubscriptionTier.pharmacyLicense:
        return 'Tvrtka licenca';
      case null:
        return raw.isEmpty ? '—' : raw;
    }
  }

  static DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _fmt(DateTime dt) {
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day.$month.${d.year}';
  }
}
