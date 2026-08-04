import '../../models/app_user.dart';
import '../../utils/currency_region_parse.dart';
import '../../utils/firestore_parse.dart';

/// Normalized seller profile map for the public storefront screen.
class StorefrontSellerData {
  const StorefrontSellerData(this.raw);

  final Map<String, dynamic> raw;

  factory StorefrontSellerData.fromMap(Map<String, dynamic>? data) {
    try {
      if (data == null || data.isEmpty) {
        return StorefrontSellerData(_emptyProfile());
      }
      return StorefrontSellerData(normalizeSellerProfileMap(data));
    } catch (_) {
      return StorefrontSellerData(_emptyProfile());
    }
  }

  String get sellerId => FirestoreParse.stringOrEmpty(raw['uid'] ?? raw['id']);
  String get name =>
      FirestoreParse.stringOrEmpty(raw['name'], fallback: 'Farmer');
  String? get profileImageUrl =>
      FirestoreParse.optionalString(raw['profileImageUrl']);
  String get address => FirestoreParse.stringOrEmpty(raw['address']);
  String get phone => FirestoreParse.stringOrEmpty(raw['phone']);
  double get avgRating => FirestoreParse.doubleOr(raw['avgRating']);
  int get reviewCount => FirestoreParse.intOr(raw['reviewCount']);
  bool get isPublicProfile =>
      FirestoreParse.boolOr(raw['isPublicProfile'], fallback: true);
  String get canonicalRole => AppUser.resolveRoleCanonical(raw);
  String? get currencyRegion =>
      CurrencyRegionParse.normalize(raw['currencyRegion']);

  static Map<String, dynamic> _emptyProfile() {
    return {
      'name': 'Farmer',
      'profileImageUrl': '',
      'address': '',
      'phone': '',
      'avgRating': 0.0,
      'reviewCount': 0,
      'isPublicProfile': true,
      'workingDays': <String>[],
      'pickupDays': <String>[],
      'deliveryDays': <String>[],
      'workingHours': '',
      'pickupHoursFrom': '',
      'pickupHoursTo': '',
      'deliveryHoursFrom': '',
      'deliveryHoursTo': '',
      'orderCurrency': 'KM',
      'maxDeliveryDistanceKm': 0.0,
      'deliveryZone1MaxKm': 0.0,
      'deliveryZone1MinOrder': 0.0,
      'deliveryZone2MaxKm': 0.0,
      'deliveryZone2MinOrder': 0.0,
      'offersPickup': true,
      'offersDelivery': false,
      'minimumOrderAmount': 0.0,
    };
  }

  static Map<String, dynamic> normalizeSellerProfileMap(
    Map<String, dynamic> data,
  ) {
    try {
      final normalized = Map<String, dynamic>.from(data);

    normalized['name'] =
        FirestoreParse.stringOrEmpty(data['name'], fallback: 'Farmer');
    normalized['profileImageUrl'] =
        FirestoreParse.optionalString(data['profileImageUrl']) ?? '';
    normalized['address'] = FirestoreParse.stringOrEmpty(data['address']);
    normalized['phone'] = FirestoreParse.stringOrEmpty(data['phone']);
    normalized['avgRating'] = FirestoreParse.doubleOr(data['avgRating']);
    normalized['reviewCount'] = FirestoreParse.intOr(data['reviewCount']);
    normalized['isPublicProfile'] =
        FirestoreParse.boolOr(data['isPublicProfile'], fallback: true);

    for (final key in ['workingDays', 'pickupDays', 'deliveryDays']) {
      normalized[key] = FirestoreParse.stringListOrEmpty(data[key]);
    }

    for (final key in [
      'workingHours',
      'pickupHoursFrom',
      'pickupHoursTo',
      'deliveryHoursFrom',
      'deliveryHoursTo',
      'orderCurrency',
    ]) {
      normalized[key] = FirestoreParse.stringOrEmpty(
        data[key],
        fallback: key == 'orderCurrency' ? 'KM' : '',
      );
    }

    normalized['isAvailable'] =
        FirestoreParse.boolOr(data['isAvailable'], fallback: true);
    normalized['offersPickup'] =
        FirestoreParse.boolOr(data['offersPickup'], fallback: true);
    normalized['offersDelivery'] =
        FirestoreParse.boolOr(data['offersDelivery'], fallback: false);

    normalized['minimumOrderAmount'] =
        FirestoreParse.doubleOr(data['minimumOrderAmount']);
    normalized['maxDeliveryDistanceKm'] =
        FirestoreParse.doubleOr(data['maxDeliveryDistanceKm']);
    normalized['deliveryZone1MaxKm'] =
        FirestoreParse.doubleOr(data['deliveryZone1MaxKm']);
    normalized['deliveryZone1MinOrder'] =
        FirestoreParse.doubleOr(data['deliveryZone1MinOrder']);
    normalized['deliveryZone2MaxKm'] =
        FirestoreParse.doubleOr(data['deliveryZone2MaxKm']);
    normalized['deliveryZone2MinOrder'] =
        FirestoreParse.doubleOr(data['deliveryZone2MinOrder']);

    final currencyRegion = CurrencyRegionParse.normalize(data['currencyRegion']);
    if (currencyRegion != null) {
      normalized['currencyRegion'] = currencyRegion;
    } else {
      normalized.remove('currencyRegion');
    }

    final farmLat = data['farmLat'];
    if (farmLat is num) {
      normalized['farmLat'] = farmLat.toDouble();
    } else {
      normalized.remove('farmLat');
    }

    final farmLng = data['farmLng'];
    if (farmLng is num) {
      normalized['farmLng'] = farmLng.toDouble();
    } else {
      normalized.remove('farmLng');
    }

    return normalized;
    } catch (_) {
      final fallback = _emptyProfile();
      fallback['uid'] =
          FirestoreParse.stringOrEmpty(data['uid'] ?? data['id']);
      fallback['name'] =
          FirestoreParse.stringOrEmpty(data['name'], fallback: 'Farmer');
      return fallback;
    }
  }
}
