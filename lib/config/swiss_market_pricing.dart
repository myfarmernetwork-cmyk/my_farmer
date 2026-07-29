/// Švicarsko tržište — de/fr/it u CH: viša cijena, isti EU limiti.
class SwissMarketPricing {
  SwissMarketPricing._();

  static const double vetEuReferenceEur = 9.99;

  /// Sidro vet paketa u CHF (~+49 % u odnosu na EU 9,99 €).
  static const double swissVetMonthlyChf = 14.90;

  static const double swissPremiumRatio =
      swissVetMonthlyChf / vetEuReferenceEur;

  static bool isSwissDeFrContext({
    String? languageCode,
    String? countryCode,
  }) {
    if (languageCode == null || languageCode.isEmpty) return false;
    final lang = languageCode.toLowerCase().split('-').first.split('_').first;
    if (lang != 'de' && lang != 'fr' && lang != 'it') return false;
    if (countryCode == null || countryCode.isEmpty) return false;
    return countryCode.toUpperCase() == 'CH';
  }

  static double adjustedEur(double baseEur) {
    return (baseEur * swissPremiumRatio * 100).round() / 100;
  }

  static double chfAmount(double baseEur) {
    final raw = baseEur * swissPremiumRatio;
    return (raw * 20).round() / 20;
  }
}
