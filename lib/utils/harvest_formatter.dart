import 'package:easy_localization/easy_localization.dart';

import 'upcoming_product_helper.dart';

class HarvestFormatter {
  HarvestFormatter._();

  static String countdownPrefix({bool isDelivery = false}) {
    return isDelivery
        ? 'delivery_countdown_prefix'.tr()
        : 'harvest_countdown_prefix'.tr();
  }

  static String countdownLabel(
    DateTime targetDateTime, {
    bool isDelivery = false,
  }) {
    final remaining = targetDateTime.difference(DateTime.now());
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return isDelivery
          ? 'delivery_countdown_due'.tr()
          : 'harvest_countdown_due'.tr();
    }

    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;

    if (isDelivery) {
      if (days > 0) {
        return 'delivery_countdown_days'.tr(
          namedArgs: {'days': '$days'},
        );
      }
      if (hours > 0) {
        return 'delivery_countdown_hours'.tr(
          namedArgs: {'hours': '$hours'},
        );
      }
      return 'delivery_countdown_soon'.tr();
    }

    if (days > 0) {
      return 'harvest_countdown_days_hours'.tr(
        namedArgs: {'days': '$days', 'hours': '$hours'},
      );
    }
    if (hours > 0) {
      return 'harvest_countdown_hours_minutes'.tr(
        namedArgs: {'hours': '$hours', 'minutes': '$minutes'},
      );
    }
    return 'harvest_countdown_minutes'.tr(
      namedArgs: {'minutes': '${remaining.inMinutes}'},
    );
  }

  static String fullCountdownLine(
    DateTime targetDateTime, {
    bool isDelivery = false,
  }) {
    return '${countdownPrefix(isDelivery: isDelivery)} '
        '${countdownLabel(targetDateTime, isDelivery: isDelivery)}';
  }

  static String formatHarvestDate(DateTime dateTime) {
    return DateFormat.yMMMd().add_Hm().format(dateTime);
  }

  static String upcomingBadge({String? upcomingMode}) {
    return UpcomingProductHelper.isDeliveryMode(upcomingMode)
        ? 'product_upcoming_delivery_badge'.tr()
        : 'product_upcoming_badge'.tr();
  }
}
