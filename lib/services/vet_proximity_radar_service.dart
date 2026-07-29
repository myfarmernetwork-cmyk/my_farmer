import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/farmer_shop_settings.dart';
import '../models/subscription_tier.dart';
import 'delivery_service.dart';

class VetProfile {
  final String uid;
  final String name;
  final String phone;
  final String address;
  final double? lat;
  final double? lng;
  final bool isPremium;
  final bool isVerified;
  final double? distanceKm;
  final bool isFavorite;

  const VetProfile({
    required this.uid,
    required this.name,
    required this.phone,
    required this.address,
    this.lat,
    this.lng,
    this.isPremium = false,
    this.isVerified = false,
    this.distanceKm,
    this.isFavorite = false,
  });

  bool get hasLocation => lat != null && lng != null;
}

class VetProximityRadarService {
  VetProximityRadarService({DeliveryService? deliveryService})
      : _deliveryService = deliveryService ?? DeliveryService();

  final DeliveryService _deliveryService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const double defaultMaxKm = 80;

  Future<VetProfile?> fetchVetById(String vetId) async {
    final doc = await _firestore.collection('users').doc(vetId).get();
    if (!doc.exists || doc.data() == null) return null;
    return _mapVet(doc.id, doc.data()!);
  }

  Future<void> setFavoriteVet({
    required String userId,
    required String? vetId,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'favoriteVetId': vetId,
    });
  }

  Future<List<VetProfile>> searchVetsByName(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return [];

    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'veterinarian')
        .where('isVerified', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => _mapVet(doc.id, doc.data()))
        .where((vet) => vet.name.toLowerCase().contains(normalized))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<VetProfile>> findPremiumVetsNearby({
    required Position buyerPosition,
    double maxKm = defaultMaxKm,
    String? favoriteVetId,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'veterinarian')
        .where('isVerified', isEqualTo: true)
        .where('premiumApprovalStatus', isEqualTo: 'APPROVED')
        .where('subscriptionTier', isEqualTo: 'veterinarian_license')
        .get();

    final ranked = <VetProfile>[];

    for (final doc in snapshot.docs) {
      final vet = _mapVet(doc.id, doc.data());
      if (!vet.isPremium) continue;

      double? distance;
      if (vet.hasLocation) {
        distance = _deliveryService.distanceKm(
          fromLat: buyerPosition.latitude,
          fromLng: buyerPosition.longitude,
          toLat: vet.lat!,
          toLng: vet.lng!,
        );
        if (distance > maxKm) continue;
      }

      ranked.add(
        VetProfile(
          uid: vet.uid,
          name: vet.name,
          phone: vet.phone,
          address: vet.address,
          lat: vet.lat,
          lng: vet.lng,
          isPremium: vet.isPremium,
          isVerified: vet.isVerified,
          distanceKm: distance,
          isFavorite: favoriteVetId != null && favoriteVetId == vet.uid,
        ),
      );
    }

    ranked.sort((a, b) {
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      final da = a.distanceKm ?? double.infinity;
      final db = b.distanceKm ?? double.infinity;
      return da.compareTo(db);
    });

    return ranked;
  }

  Future<List<VetProfile>> resolveFirstAidVets({
    required Position? buyerPosition,
    String? favoriteVetId,
  }) async {
    final results = <VetProfile>[];
    final seen = <String>{};

    if (favoriteVetId != null && favoriteVetId.isNotEmpty) {
      final favorite = await fetchVetById(favoriteVetId);
      if (favorite != null && favorite.isVerified) {
        results.add(
          VetProfile(
            uid: favorite.uid,
            name: favorite.name,
            phone: favorite.phone,
            address: favorite.address,
            lat: favorite.lat,
            lng: favorite.lng,
            isPremium: favorite.isPremium,
            isVerified: favorite.isVerified,
            distanceKm: buyerPosition != null && favorite.hasLocation
                ? _deliveryService.distanceKm(
                    fromLat: buyerPosition.latitude,
                    fromLng: buyerPosition.longitude,
                    toLat: favorite.lat!,
                    toLng: favorite.lng!,
                  )
                : null,
            isFavorite: true,
          ),
        );
        seen.add(favorite.uid);
      }
    }

    if (buyerPosition != null) {
      final nearby = await findPremiumVetsNearby(
        buyerPosition: buyerPosition,
        favoriteVetId: favoriteVetId,
      );
      for (final vet in nearby) {
        if (seen.contains(vet.uid)) continue;
        results.add(vet);
        seen.add(vet.uid);
      }
    }

    return results;
  }

  VetProfile _mapVet(String uid, Map<String, dynamic> data) {
    final shop = FarmerShopSettings.fromMap(data);
    return VetProfile(
      uid: uid,
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      lat: shop.farmLat,
      lng: shop.farmLng,
      isPremium: data['subscriptionTier'] ==
              SubscriptionTier.veterinarianLicense.firestoreValue &&
          data['premiumApprovalStatus']?.toString().toUpperCase() == 'APPROVED',
      isVerified: data['isVerified'] == true,
    );
  }
}

final vetProximityRadarServiceProvider =
    Provider<VetProximityRadarService>((ref) {
  return VetProximityRadarService();
});
