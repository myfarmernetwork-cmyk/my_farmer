import '../utils/weekday_localization.dart';

enum DeliveryOption {
  pickup,
  delivery;

  String get firestoreValue => name;

  static DeliveryOption fromString(String? value) {
    if (value == DeliveryOption.delivery.name) {
      return DeliveryOption.delivery;
    }
    return DeliveryOption.pickup;
  }
}

class FarmerShopSettings {
  final List<String> workingDays;
  final String workingHours;
  final bool isAvailable;
  final double minimumOrderAmount;
  final String orderCurrency;
  final bool offersPickup;
  final bool offersDelivery;
  final double maxDeliveryDistanceKm;
  final double deliveryZone1MaxKm;
  final double deliveryZone1MinOrder;
  final double deliveryZone2MaxKm;
  final double deliveryZone2MinOrder;
  final List<String> pickupDays;
  final String pickupHoursFrom;
  final String pickupHoursTo;
  final List<String> deliveryDays;
  final String deliveryHoursFrom;
  final String deliveryHoursTo;
  final double? farmLat;
  final double? farmLng;

  const FarmerShopSettings({
    this.workingDays = const [],
    this.workingHours = '',
    this.isAvailable = true,
    this.minimumOrderAmount = 0,
    this.orderCurrency = 'KM',
    this.offersPickup = true,
    this.offersDelivery = false,
    this.maxDeliveryDistanceKm = 0,
    this.deliveryZone1MaxKm = 5,
    this.deliveryZone1MinOrder = 20,
    this.deliveryZone2MaxKm = 10,
    this.deliveryZone2MinOrder = 30,
    this.pickupDays = const [],
    this.pickupHoursFrom = '',
    this.pickupHoursTo = '',
    this.deliveryDays = const [],
    this.deliveryHoursFrom = '',
    this.deliveryHoursTo = '',
    this.farmLat,
    this.farmLng,
  });

  static const allWeekDays = WeekdayLocalization.codes;

  static double _asDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static List<String> _asStringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  factory FarmerShopSettings.fromMap(Map<String, dynamic> data) {
    final days = WeekdayLocalization.normalizeList(_asStringList(data['workingDays']));
    final minimum = _asDouble(data['minimumOrderAmount']);
    final maxDelivery = _asDouble(data['maxDeliveryDistanceKm']);

    double? farmLat;
    final rawLat = data['farmLat'];
    if (rawLat is num) farmLat = rawLat.toDouble();

    double? farmLng;
    final rawLng = data['farmLng'];
    if (rawLng is num) farmLng = rawLng.toDouble();

    final zone2Max = _asDouble(data['deliveryZone2MaxKm'], maxDelivery > 0 ? maxDelivery : 10);
    final zone1Max = _asDouble(data['deliveryZone1MaxKm'], zone2Max > 0 ? zone2Max / 2 : 5);

    return FarmerShopSettings(
      workingDays: days,
      workingHours: data['workingHours'] as String? ?? '',
      isAvailable: data['isAvailable'] as bool? ?? true,
      minimumOrderAmount: minimum,
      orderCurrency: data['orderCurrency'] as String? ?? 'KM',
      offersPickup: data['offersPickup'] as bool? ?? true,
      offersDelivery: data['offersDelivery'] as bool? ?? false,
      maxDeliveryDistanceKm: maxDelivery > 0 ? maxDelivery : zone2Max,
      deliveryZone1MaxKm: zone1Max,
      deliveryZone1MinOrder:
          _asDouble(data['deliveryZone1MinOrder'], minimum > 0 ? minimum : 20),
      deliveryZone2MaxKm: zone2Max,
      deliveryZone2MinOrder:
          _asDouble(data['deliveryZone2MinOrder'], minimum > 0 ? minimum + 10 : 30),
      pickupDays: WeekdayLocalization.normalizeList(_asStringList(data['pickupDays'])),
      pickupHoursFrom: data['pickupHoursFrom'] as String? ?? '',
      pickupHoursTo: data['pickupHoursTo'] as String? ?? '',
      deliveryDays: WeekdayLocalization.normalizeList(_asStringList(data['deliveryDays'])),
      deliveryHoursFrom: data['deliveryHoursFrom'] as String? ?? '',
      deliveryHoursTo: data['deliveryHoursTo'] as String? ?? '',
      farmLat: farmLat,
      farmLng: farmLng,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workingDays': workingDays,
      'workingHours': workingHours,
      'isAvailable': isAvailable,
      'minimumOrderAmount': minimumOrderAmount,
      'orderCurrency': orderCurrency,
      'offersPickup': offersPickup,
      'offersDelivery': offersDelivery,
      'maxDeliveryDistanceKm':
          maxDeliveryDistanceKm > 0 ? maxDeliveryDistanceKm : deliveryZone2MaxKm,
      'deliveryZone1MaxKm': deliveryZone1MaxKm,
      'deliveryZone1MinOrder': deliveryZone1MinOrder,
      'deliveryZone2MaxKm': deliveryZone2MaxKm,
      'deliveryZone2MinOrder': deliveryZone2MinOrder,
      'pickupDays': pickupDays,
      'pickupHoursFrom': pickupHoursFrom,
      'pickupHoursTo': pickupHoursTo,
      'deliveryDays': deliveryDays,
      'deliveryHoursFrom': deliveryHoursFrom,
      'deliveryHoursTo': deliveryHoursTo,
      if (farmLat != null) 'farmLat': farmLat,
      if (farmLng != null) 'farmLng': farmLng,
    };
  }

  bool get hasFarmLocation => farmLat != null && farmLng != null;

  String get workingDaysLabel {
    if (workingDays.isEmpty) return 'Nije navedeno';
    return workingDays.join(', ');
  }

  String get availabilityLabel => isAvailable ? 'Dostupan' : 'Nedostupan';

  String get minimumOrderLabel {
    if (deliveryZone1MinOrder <= 0 && deliveryZone2MinOrder <= 0) {
      return 'Bez minimalnog iznosa';
    }
    return 'Zone: do ${deliveryZone1MaxKm.toStringAsFixed(0)} km min. '
        '${deliveryZone1MinOrder.toStringAsFixed(0)} $orderCurrency · '
        'do ${deliveryZone2MaxKm.toStringAsFixed(0)} km min. '
        '${deliveryZone2MinOrder.toStringAsFixed(0)} $orderCurrency';
  }

  String get pickupScheduleLabel {
    if (pickupDays.isEmpty && pickupHoursFrom.isEmpty) {
      return workingDays.isEmpty ? 'Nije navedeno' : '$workingDaysLabel · $workingHours';
    }
    final days = pickupDays.isEmpty ? workingDaysLabel : pickupDays.join(', ');
    final hours = _hoursRange(pickupHoursFrom, pickupHoursTo);
    return hours.isEmpty ? days : '$days · $hours';
  }

  String get deliveryScheduleLabel {
    if (deliveryDays.isEmpty && deliveryHoursFrom.isEmpty) {
      return 'Nije navedeno';
    }
    final days = deliveryDays.join(', ');
    final hours = _hoursRange(deliveryHoursFrom, deliveryHoursTo);
    return hours.isEmpty ? days : '$days · $hours';
  }

  String _hoursRange(String from, String to) {
    if (from.isEmpty && to.isEmpty) return '';
    if (to.isEmpty) return from;
    return '$from - $to';
  }

  String get deliveryOptionsLabel {
    final options = <String>[];
    if (offersPickup) options.add('Osobno preuzimanje');
    if (offersDelivery) {
      options.add(
        'Dostava do ${(maxDeliveryDistanceKm > 0 ? maxDeliveryDistanceKm : deliveryZone2MaxKm).toStringAsFixed(0)} km',
      );
    }
    if (options.isEmpty) return 'Nije navedeno';
    return options.join(' · ');
  }

  String get deliveryZonesLabel {
    return 'Do ${deliveryZone1MaxKm.toStringAsFixed(0)} km: min. '
        '${deliveryZone1MinOrder.toStringAsFixed(0)} $orderCurrency · '
        '${deliveryZone1MaxKm.toStringAsFixed(0)}–${deliveryZone2MaxKm.toStringAsFixed(0)} km: min. '
        '${deliveryZone2MinOrder.toStringAsFixed(0)} $orderCurrency';
  }

  DeliveryOption get defaultDeliveryOption {
    if (offersPickup) return DeliveryOption.pickup;
    if (offersDelivery) return DeliveryOption.delivery;
    return DeliveryOption.pickup;
  }

  double minimumForDeliveryDistance(double? distanceKm) {
    if (distanceKm == null) {
      return deliveryZone1MinOrder > 0
          ? deliveryZone1MinOrder
          : minimumOrderAmount;
    }
    if (distanceKm <= deliveryZone1MaxKm) return deliveryZone1MinOrder;
    if (distanceKm <= deliveryZone2MaxKm) return deliveryZone2MinOrder;
    return double.infinity;
  }

  bool isWithinDeliveryRange(double? distanceKm) {
    if (distanceKm == null) return true;
    final maxKm =
        maxDeliveryDistanceKm > 0 ? maxDeliveryDistanceKm : deliveryZone2MaxKm;
    return distanceKm <= maxKm;
  }

  bool meetsMinimum(double amount, {DeliveryOption? option, double? distanceKm}) {
    if (option == DeliveryOption.pickup) return true;
    if (option == DeliveryOption.delivery) {
      final min = minimumForDeliveryDistance(distanceKm);
      if (min.isInfinite) return false;
      return amount >= min;
    }
    if (minimumOrderAmount <= 0) return true;
    return amount >= minimumOrderAmount;
  }
}

class CartSellerIssue {
  final String sellerId;
  final String sellerName;
  final String message;

  const CartSellerIssue({
    required this.sellerId,
    required this.sellerName,
    required this.message,
  });
}
