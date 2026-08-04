import 'package:easy_localization/easy_localization.dart';

import '../models/farmer_shop_settings.dart';
import 'weekday_localization.dart';

class FarmerShopLocalization {
  static String availability(bool isAvailable) =>
      isAvailable ? 'profile_available'.tr() : 'profile_unavailable'.tr();

  static String workingDays(FarmerShopSettings settings) =>
      WeekdayLocalization.formatList(settings.workingDays);

  static String pickupDays(FarmerShopSettings settings) {
    if (settings.pickupDays.isEmpty && settings.pickupHoursFrom.isEmpty) {
      if (settings.workingDays.isEmpty) return 'shop_not_specified'.tr();
      return _appendHours(workingDays(settings), settings.workingHours);
    }
    final days = settings.pickupDays.isEmpty
        ? workingDays(settings)
        : WeekdayLocalization.formatList(settings.pickupDays);
    return _appendHours(days, _hoursRange(settings.pickupHoursFrom, settings.pickupHoursTo));
  }

  static String deliveryDays(FarmerShopSettings settings) {
    if (settings.deliveryDays.isEmpty && settings.deliveryHoursFrom.isEmpty) {
      return 'shop_not_specified'.tr();
    }
    final days = WeekdayLocalization.formatList(settings.deliveryDays);
    return _appendHours(days, _hoursRange(settings.deliveryHoursFrom, settings.deliveryHoursTo));
  }

  static String minimumOrder(FarmerShopSettings settings) {
    if (settings.deliveryZone1MinOrder <= 0 &&
        settings.deliveryZone2MinOrder <= 0) {
      return 'shop_no_minimum'.tr();
    }
    return 'shop_zones_summary'.tr(namedArgs: {
      'km1': settings.deliveryZone1MaxKm.toStringAsFixed(0),
      'min1': settings.deliveryZone1MinOrder.toStringAsFixed(0),
      'currency': settings.orderCurrency,
      'km2': settings.deliveryZone2MaxKm.toStringAsFixed(0),
      'min2': settings.deliveryZone2MinOrder.toStringAsFixed(0),
    });
  }

  static String deliveryZones(FarmerShopSettings settings) {
    if (!settings.hasDeliveryZonesConfigured) {
      return 'shop_not_specified'.tr();
    }
    return 'shop_delivery_zones_detail'.tr(namedArgs: {
      'km1': settings.deliveryZone1MaxKm.toStringAsFixed(0),
      'min1': settings.deliveryZone1MinOrder.toStringAsFixed(0),
      'currency': settings.orderCurrency,
      'km1b': settings.deliveryZone1MaxKm.toStringAsFixed(0),
      'km2': settings.deliveryZone2MaxKm.toStringAsFixed(0),
      'min2': settings.deliveryZone2MinOrder.toStringAsFixed(0),
    });
  }

  static String deliveryOptions(FarmerShopSettings settings) {
    final options = <String>[];
    if (settings.offersPickup) options.add('cart_pickup'.tr());
    if (settings.offersDelivery) {
      final maxKm = settings.effectiveMaxDeliveryDistanceKm;
      if (maxKm > 0) {
        options.add(
          'shop_delivery_up_to_km'.tr(
            namedArgs: {'km': maxKm.toStringAsFixed(0)},
          ),
        );
      } else {
        options.add('cart_delivery'.tr());
      }
    }
    if (options.isEmpty) return 'shop_not_specified'.tr();
    return options.join(' · ');
  }

  static String deliveryOptionLabel(String firestoreValue) {
    if (firestoreValue == 'delivery') return 'cart_delivery'.tr();
    return 'cart_pickup'.tr();
  }

  static String _hoursRange(String from, String to) {
    if (from.isEmpty && to.isEmpty) return '';
    if (to.isEmpty) return from;
    return '$from - $to';
  }

  static String _appendHours(String days, String hours) {
    if (hours.isEmpty) return days;
    return '$days · $hours';
  }
}
