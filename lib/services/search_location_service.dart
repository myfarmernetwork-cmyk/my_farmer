import 'package:geolocator/geolocator.dart';

import '../models/farmer_shop_settings.dart';
import '../models/product.dart';
import '../models/search_radius.dart';
import 'delivery_service.dart';

class SearchLocationService {
  SearchLocationService({DeliveryService? deliveryService})
      : _deliveryService = deliveryService ?? DeliveryService();

  final DeliveryService _deliveryService;

  ({double lat, double lng})? resolveCoordinates(
    Product product,
    Map<String, FarmerShopSettings> sellerSettings,
  ) {
    final seller = sellerSettings[product.sellerId];
    if (seller?.hasFarmLocation == true) {
      return (lat: seller!.farmLat!, lng: seller.farmLng!);
    }
    if (product.lat != 0 || product.lng != 0) {
      return (lat: product.lat, lng: product.lng);
    }
    return null;
  }

  double? distanceKm({
    required Position buyerPosition,
    required Product product,
    required Map<String, FarmerShopSettings> sellerSettings,
  }) {
    final coords = resolveCoordinates(product, sellerSettings);
    if (coords == null) return null;

    return _deliveryService.distanceKm(
      fromLat: buyerPosition.latitude,
      fromLng: buyerPosition.longitude,
      toLat: coords.lat,
      toLng: coords.lng,
    );
  }

  List<RankedProduct> filterAndSort({
    required List<Product> products,
    required Map<String, FarmerShopSettings> sellerSettings,
    required SearchRadius radius,
    Position? buyerPosition,
  }) {
    final ranked = <RankedProduct>[];

    for (final product in products) {
      double? distance;
      if (buyerPosition != null) {
        distance = distanceKm(
          buyerPosition: buyerPosition,
          product: product,
          sellerSettings: sellerSettings,
        );
      }

      if (!radius.isAll) {
        if (distance == null) continue;
        if (distance > radius.maxKm!) continue;
      }

      ranked.add(RankedProduct(product: product, distanceKm: distance));
    }

    ranked.sort((a, b) {
      final da = a.distanceKm ?? double.infinity;
      final db = b.distanceKm ?? double.infinity;
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
      return a.product.name.compareTo(b.product.name);
    });

    return ranked;
  }

  Future<Position?> getBuyerPosition() => _deliveryService.getCurrentPosition();
}
