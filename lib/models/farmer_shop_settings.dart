import '../utils/weekday_localization.dart';

import '../utils/firestore_parse.dart';



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

    this.deliveryZone1MaxKm = 0,

    this.deliveryZone1MinOrder = 0,

    this.deliveryZone2MaxKm = 0,

    this.deliveryZone2MinOrder = 0,

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



  bool get hasDeliveryZonesConfigured =>

      deliveryZone1MaxKm > 0 ||

      deliveryZone2MaxKm > 0 ||

      deliveryZone1MinOrder > 0 ||

      deliveryZone2MinOrder > 0;



  bool get hasDeliveryScheduleConfigured =>

      deliveryDays.isNotEmpty ||

      deliveryHoursFrom.isNotEmpty ||

      deliveryHoursTo.isNotEmpty;



  static List<String> _normalizedWeekdays(dynamic raw) {

    return WeekdayLocalization.normalizeList(

      FirestoreParse.stringListOrEmpty(raw),

    );

  }



  static double? _optionalCoordinate(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }



  factory FarmerShopSettings.fromMap(Map<String, dynamic>? data) {

    if (data == null || data.isEmpty) {

      return const FarmerShopSettings();

    }

    return tryFromMap(data) ?? const FarmerShopSettings();

  }



  static FarmerShopSettings? tryFromMap(Map<String, dynamic> data) {

    try {

      return FarmerShopSettings(

        workingDays: _normalizedWeekdays(data['workingDays']),

        workingHours: FirestoreParse.stringOrEmpty(data['workingHours']),

        isAvailable: FirestoreParse.boolOr(data['isAvailable'], fallback: true),

        minimumOrderAmount:

            FirestoreParse.doubleOr(data['minimumOrderAmount']),

        orderCurrency: FirestoreParse.stringOrEmpty(

          data['orderCurrency'],

          fallback: 'KM',

        ),

        offersPickup: FirestoreParse.boolOr(data['offersPickup'], fallback: true),

        offersDelivery: FirestoreParse.boolOr(data['offersDelivery']),

        maxDeliveryDistanceKm:

            FirestoreParse.doubleOr(data['maxDeliveryDistanceKm']),

        deliveryZone1MaxKm:

            FirestoreParse.doubleOr(data['deliveryZone1MaxKm']),

        deliveryZone1MinOrder:

            FirestoreParse.doubleOr(data['deliveryZone1MinOrder']),

        deliveryZone2MaxKm:

            FirestoreParse.doubleOr(data['deliveryZone2MaxKm']),

        deliveryZone2MinOrder:

            FirestoreParse.doubleOr(data['deliveryZone2MinOrder']),

        pickupDays: _normalizedWeekdays(data['pickupDays']),

        pickupHoursFrom: FirestoreParse.stringOrEmpty(data['pickupHoursFrom']),

        pickupHoursTo: FirestoreParse.stringOrEmpty(data['pickupHoursTo']),

        deliveryDays: _normalizedWeekdays(data['deliveryDays']),

        deliveryHoursFrom:

            FirestoreParse.stringOrEmpty(data['deliveryHoursFrom']),

        deliveryHoursTo: FirestoreParse.stringOrEmpty(data['deliveryHoursTo']),

        farmLat: _optionalCoordinate(data['farmLat']),

        farmLng: _optionalCoordinate(data['farmLng']),

      );

    } catch (_) {

      return null;

    }

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

      'maxDeliveryDistanceKm': maxDeliveryDistanceKm,

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

    if (!hasDeliveryScheduleConfigured) {

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

      final maxKm = effectiveMaxDeliveryDistanceKm;

      if (maxKm > 0) {

        options.add('Dostava do ${maxKm.toStringAsFixed(0)} km');

      } else {

        options.add('Dostava');

      }

    }

    if (options.isEmpty) return 'Nije navedeno';

    return options.join(' · ');

  }



  double get effectiveMaxDeliveryDistanceKm {

    if (maxDeliveryDistanceKm > 0) return maxDeliveryDistanceKm;

    if (deliveryZone2MaxKm > 0) return deliveryZone2MaxKm;

    return deliveryZone1MaxKm;

  }



  String get deliveryZonesLabel {

    if (!hasDeliveryZonesConfigured) return 'Nije navedeno';

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

    if (!hasDeliveryZonesConfigured) {

      return minimumOrderAmount > 0 ? minimumOrderAmount : 0;

    }

    if (distanceKm == null) {

      return deliveryZone1MinOrder > 0

          ? deliveryZone1MinOrder

          : minimumOrderAmount;

    }

    if (deliveryZone1MaxKm > 0 && distanceKm <= deliveryZone1MaxKm) {

      return deliveryZone1MinOrder;

    }

    if (deliveryZone2MaxKm > 0 && distanceKm <= deliveryZone2MaxKm) {

      return deliveryZone2MinOrder;

    }

    return double.infinity;

  }



  bool isWithinDeliveryRange(double? distanceKm) {

    if (distanceKm == null) return true;

    final maxKm = effectiveMaxDeliveryDistanceKm;

    if (maxKm <= 0) return true;

    return distanceKm <= maxKm;

  }



  bool meetsMinimum(double amount, {DeliveryOption? option, double? distanceKm}) {

    if (option == DeliveryOption.pickup) return true;

    if (option == DeliveryOption.delivery) {

      final min = minimumForDeliveryDistance(distanceKm);

      if (min.isInfinite) return false;

      if (min <= 0) return true;

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


