/// Tursko tržište — iznad BiH (25 skenova), ispod punog EU paketa.
///
/// Sidro 7,99 € (BiH i EU imaju 9,99 nominalno; Turska ima viši standard od BiH).
/// Skenovi proporcionalno (~40 vet / mj. umjesto 25 BiH ili 50 EU).
class TurkeyMarketPricing {
  TurkeyMarketPricing._();

  static const double vetEuReferenceEur = 9.99;
  static const double turkeyVetAnchorEur = 7.99;
  static const double turkeyPriceRatio =
      turkeyVetAnchorEur / vetEuReferenceEur;

  static bool isTurkishLanguage(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return false;
    return languageCode.toLowerCase().split('-').first.split('_').first == 'tr';
  }

  static bool isTurkeyPricingContext({
    String? languageCode,
    String? countryCode,
  }) {
    final code = (countryCode ?? '').toUpperCase();
    return code == 'TR';
  }

  static double adjustedEur(double baseEur) {
    return (baseEur * turkeyPriceRatio * 100).round() / 100;
  }

  static int adjustedScanCap(int euCap) {
    final cap = (euCap * turkeyPriceRatio).round();
    return cap < 3 ? 3 : cap;
  }
}
