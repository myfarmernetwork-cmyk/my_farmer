import '../models/product_units.dart';

class QuantityHelper {
  static const double _kgStep = 0.25;

  static bool usesDecimalSteps(String unit) =>
      ProductUnits.normalize(unit) == 'kg';

  static double step(String unit) => usesDecimalSteps(unit) ? _kgStep : 1.0;

  static double minimum(String unit) => step(unit);

  static double normalize(double quantity, String unit) {
    final s = step(unit);
    if (quantity <= 0) return minimum(unit);
    final steps = (quantity / s).round();
    final normalized = steps * s;
    return double.parse(normalized.toStringAsFixed(4));
  }

  static double increase(double quantity, String unit) =>
      normalize(quantity + step(unit), unit);

  static double decrease(double quantity, String unit) {
    final next = quantity - step(unit);
    if (next < minimum(unit) - 0.0001) return 0;
    return normalize(next, unit);
  }

  static String formatValue(double quantity, String unit) {
    final rounded = normalize(quantity, unit);
    if ((rounded - rounded.roundToDouble()).abs() < 0.001) {
      return rounded.toInt().toString();
    }

    var text = rounded.toStringAsFixed(2);
    text = text.replaceAll(RegExp(r'0+$'), '');
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  static String formatWithUnit(double quantity, String unit) {
    final normalized = normalize(quantity, unit);
    return '${formatValue(normalized, unit)} ${ProductUnits.shortLabel(unit)}';
  }

  static bool shouldShowLineTotal(double quantity, String unit) {
    if (usesDecimalSteps(unit)) {
      return quantity > minimum(unit) + 0.0001;
    }
    return quantity > 1;
  }
}
