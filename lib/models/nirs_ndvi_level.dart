/// NDVI pragovi usklađeni sa Sentinel-2 praksom (priprema za live API).
class NirsNdviLevel {
  NirsNdviLevel._();

  static const double goodMin = 0.65;
  static const double moderateMin = 0.45;

  static String healthKeyFor(double ndvi) {
    if (ndvi >= goodMin) return 'land_nirs_health_good';
    if (ndvi >= moderateMin) return 'land_nirs_health_moderate';
    return 'land_nirs_health_low';
  }

  static String adviceKeyFor({
    required double ndvi,
    required double moistureIndex,
  }) {
    if (moistureIndex < 40) return 'land_nirs_advice_low_moisture';
    if (moistureIndex > 85) return 'land_nirs_advice_high_moisture';
    if (ndvi >= goodMin) return 'land_nirs_advice_good';
    if (ndvi >= moderateMin) return 'land_nirs_advice_moderate';
    return 'land_nirs_advice_low';
  }
}
