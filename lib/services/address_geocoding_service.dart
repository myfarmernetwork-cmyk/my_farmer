import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

/// Pretvara ulicu + grad + državu u koordinate kad GPS nije dostupan.
class AddressGeocodingService {
  AddressGeocodingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static final Map<String, ({double lat, double lng})> _memoryCache = {};

  static String normalizeAddress(String address) =>
      address.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<({double lat, double lng})?> geocode(String address) async {
    final normalized = normalizeAddress(address);
    if (normalized.length < 5) return null;

    final cached = _memoryCache[normalized];
    if (cached != null) return cached;

    try {
      final results = await locationFromAddress(address.trim());
      if (results.isEmpty) return null;

      final loc = results.first;
      if (loc.latitude == 0 && loc.longitude == 0) return null;

      final coords = (lat: loc.latitude, lng: loc.longitude);
      _memoryCache[normalized] = coords;
      return coords;
    } catch (_) {
      return null;
    }
  }

  Future<({double lat, double lng})?> resolveCoordinates({
    required String? address,
    double? lat,
    double? lng,
    String? userId,
    bool persist = true,
  }) async {
    if (lat != null && lng != null) {
      return (lat: lat, lng: lng);
    }

    final trimmed = address?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final geocoded = await geocode(trimmed);
    if (geocoded == null) return null;

    if (persist && userId != null && userId.isNotEmpty) {
      await persistForUser(userId, geocoded.lat, geocoded.lng);
    }

    return geocoded;
  }

  Future<void> persistForUser(String uid, double lat, double lng) async {
    await _firestore.collection('users').doc(uid).set(
      {
        'farmLat': lat,
        'farmLng': lng,
      },
      SetOptions(merge: true),
    );
  }
}
