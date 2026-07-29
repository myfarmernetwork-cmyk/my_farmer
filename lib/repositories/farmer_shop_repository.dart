import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/cart_item.dart';
import '../models/farmer_shop_settings.dart';
import '../services/delivery_service.dart';

class FarmerShopRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeliveryService _deliveryService = DeliveryService();

  Future<FarmerShopSettings> getSettings(String sellerId) async {
    final doc = await _firestore.collection('users').doc(sellerId).get();
    if (!doc.exists) return const FarmerShopSettings();
    return FarmerShopSettings.fromMap(doc.data() ?? {});
  }

  Future<Map<String, FarmerShopSettings>> getSettingsForSellers(
    Iterable<String> sellerIds,
  ) async {
    final uniqueIds = sellerIds.toSet();
    final result = <String, FarmerShopSettings>{};

    await Future.wait(
      uniqueIds.map((id) async {
        result[id] = await getSettings(id);
      }),
    );

    return result;
  }

  double? _distanceKm(FarmerShopSettings settings, Position? buyerPosition) {
    if (buyerPosition == null || !settings.hasFarmLocation) return null;
    return _deliveryService.distanceKm(
      fromLat: settings.farmLat!,
      fromLng: settings.farmLng!,
      toLat: buyerPosition.latitude,
      toLng: buyerPosition.longitude,
    );
  }

  Future<List<CartSellerIssue>> validateCartItems({
    required List<CartItem> items,
    Map<String, DeliveryOption>? deliveryBySeller,
    Position? buyerPosition,
  }) async {
    if (items.isEmpty) return [];

    final grouped = <String, List<CartItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.sellerId, () => []).add(item);
    }

    final settingsMap = await getSettingsForSellers(grouped.keys);
    final issues = <CartSellerIssue>[];

    for (final entry in grouped.entries) {
      final sellerId = entry.key;
      final sellerItems = entry.value;
      final sellerName = sellerItems.first.sellerName;
      final total = sellerItems.fold(0.0, (sum, item) => sum + item.lineTotal);
      final settings =
          settingsMap[sellerId] ?? const FarmerShopSettings();
      final deliveryChoice = deliveryBySeller?[sellerId] ??
          settings.defaultDeliveryOption;

      if (!settings.isAvailable) {
        issues.add(
          CartSellerIssue(
            sellerId: sellerId,
            sellerName: sellerName,
            message: 'product_seller_unavailable'.tr(
              namedArgs: {'name': sellerName},
            ),
          ),
        );
        continue;
      }

      if (deliveryChoice == DeliveryOption.pickup) {
        continue;
      }

      final distanceKm = _distanceKm(settings, buyerPosition);

      if (!settings.isWithinDeliveryRange(distanceKm)) {
        issues.add(
          CartSellerIssue(
            sellerId: sellerId,
            sellerName: sellerName,
            message: 'cart_delivery_out_of_range'.tr(namedArgs: {
              'name': sellerName,
              'maxKm': settings.deliveryZone2MaxKm.toStringAsFixed(0),
            }),
          ),
        );
        continue;
      }

      if (!settings.meetsMinimum(
        total,
        option: DeliveryOption.delivery,
        distanceKm: distanceKm,
      )) {
        final min = settings.minimumForDeliveryDistance(distanceKm);
        final inZone1 = distanceKm != null &&
            distanceKm <= settings.deliveryZone1MaxKm;
        issues.add(
          CartSellerIssue(
            sellerId: sellerId,
            sellerName: sellerName,
            message: (inZone1
                    ? 'cart_min_order_zone_near'
                    : 'cart_min_order_zone_far')
                .tr(namedArgs: {
              'name': sellerName,
              'maxKm': settings.deliveryZone1MaxKm.toStringAsFixed(0),
              'km1': settings.deliveryZone1MaxKm.toStringAsFixed(0),
              'km2': settings.deliveryZone2MaxKm.toStringAsFixed(0),
              'amount': min.toStringAsFixed(2),
              'currency': settings.orderCurrency,
            }),
          ),
        );
      }
    }

    return issues;
  }

  Future<List<CartSellerIssue>> validateDeliveryChoices({
    required List<CartItem> items,
    required Map<String, DeliveryOption> deliveryBySeller,
    Position? buyerPosition,
  }) async {
    if (items.isEmpty) return [];

    final grouped = <String, List<CartItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.sellerId, () => []).add(item);
    }

    final settingsMap = await getSettingsForSellers(grouped.keys);
    final issues = <CartSellerIssue>[];

    for (final sellerId in grouped.keys) {
      final sellerName = grouped[sellerId]!.first.sellerName;
      final settings = settingsMap[sellerId] ?? const FarmerShopSettings();
      final choice =
          deliveryBySeller[sellerId] ?? settings.defaultDeliveryOption;

      if (choice == DeliveryOption.pickup) continue;

      if (!settings.offersDelivery) {
        issues.add(
          CartSellerIssue(
            sellerId: sellerId,
            sellerName: sellerName,
            message: 'cart_seller_no_delivery'.tr(
              namedArgs: {'name': sellerName},
            ),
          ),
        );
        continue;
      }

      if (!settings.hasFarmLocation) {
        issues.add(
          CartSellerIssue(
            sellerId: sellerId,
            sellerName: sellerName,
            message: 'cart_seller_no_farm_location'.tr(
              namedArgs: {'name': sellerName},
            ),
          ),
        );
        continue;
      }

      Position? position = buyerPosition;
      position ??= await _deliveryService.getCurrentPosition();

      if (position == null) {
        issues.add(
          CartSellerIssue(
            sellerId: sellerId,
            sellerName: sellerName,
            message: 'cart_gps_required_for_seller'.tr(
              namedArgs: {'name': sellerName},
            ),
          ),
        );
        continue;
      }

      final distanceKm = _distanceKm(settings, position);
      if (distanceKm != null &&
          !settings.isWithinDeliveryRange(distanceKm)) {
        issues.add(
          CartSellerIssue(
            sellerId: sellerId,
            sellerName: sellerName,
            message: 'cart_delivery_too_far_detail'.tr(namedArgs: {
              'name': sellerName,
              'distanceKm': distanceKm.toStringAsFixed(1),
              'maxKm': settings.deliveryZone2MaxKm.toStringAsFixed(0),
            }),
          ),
        );
      }
    }

    return issues;
  }

  Future<CartSellerIssue?> validateSingleProduct({
    required String sellerId,
    required String sellerName,
    required double amount,
    DeliveryOption deliveryOption = DeliveryOption.pickup,
    Position? buyerPosition,
  }) async {
    final settings = await getSettings(sellerId);

    if (!settings.isAvailable) {
      return CartSellerIssue(
        sellerId: sellerId,
        sellerName: sellerName,
        message: 'product_seller_unavailable'.tr(
          namedArgs: {'name': sellerName},
        ),
      );
    }

    if (deliveryOption == DeliveryOption.pickup) return null;

    final distanceKm = _distanceKm(settings, buyerPosition);
    if (!settings.meetsMinimum(
      amount,
      option: DeliveryOption.delivery,
      distanceKm: distanceKm,
    )) {
      final min = settings.minimumForDeliveryDistance(distanceKm);
      return CartSellerIssue(
        sellerId: sellerId,
        sellerName: sellerName,
        message: 'product_min_order_required'.tr(namedArgs: {
          'amount': min.toStringAsFixed(2),
          'currency': settings.orderCurrency,
        }),
      );
    }

    return null;
  }
}

final farmerShopRepositoryProvider = Provider<FarmerShopRepository>(
  (ref) => FarmerShopRepository(),
);

final farmerShopSettingsProvider = FutureProvider.autoDispose
    .family<FarmerShopSettings, String>((ref, sellerId) {
  return ref.watch(farmerShopRepositoryProvider).getSettings(sellerId);
});
