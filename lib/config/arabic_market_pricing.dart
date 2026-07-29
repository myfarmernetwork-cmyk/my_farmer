/// Arapsko / MENA tržište — cijena i valuta prema GPS državi.
enum ArabicPricingTier {
  /// Zaljev (SA, AE, QA, KW, OM, BH) — puna EU razina.
  gcc,

  /// Maghreb i Levant (EG, MA, TN, DZ, JO...) — ~50 % EU cijene.
  standard,

  /// Ostale arapske zemlje — ~30 % EU cijene (kao Kenya/Indija).
  emerging,
}

class ArabicMarketPricing {
  ArabicMarketPricing._();

  static const double vetEuReferenceEur = 9.99;
  static const double gccVetAnchorEur = 9.99;
  static const double standardVetAnchorEur = 4.99;
  static const double emergingVetAnchorEur = 2.99;

  static const Set<String> gccCountries = {
    'SA',
    'AE',
    'QA',
    'KW',
    'OM',
    'BH',
  };

  static const Set<String> standardCountries = {
    'EG',
    'MA',
    'TN',
    'DZ',
    'JO',
    'LB',
    'IQ',
    'PS',
    'SY',
    'YE',
    'LY',
    'SD',
    'MR',
  };

  static const Set<String> arabCountries = {
    ...gccCountries,
    ...standardCountries,
    'SO',
    'DJ',
    'KM',
    'ER',
  };

  static bool isArabicLanguage(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return false;
    return languageCode.toLowerCase().split('-').first.split('_').first == 'ar';
  }

  static bool isArabicPricingContext({
    String? languageCode,
    String? countryCode,
  }) {
    final code = (countryCode ?? '').toUpperCase();
    return arabCountries.contains(code);
  }

  static ArabicPricingTier tierForCountry(String? countryCode) {
    final code = (countryCode ?? 'SA').toUpperCase();
    if (gccCountries.contains(code)) return ArabicPricingTier.gcc;
    if (standardCountries.contains(code)) return ArabicPricingTier.standard;
    if (arabCountries.contains(code)) return ArabicPricingTier.emerging;
    return ArabicPricingTier.gcc;
  }

  static double vetAnchorEurForCountry(String? countryCode) {
    switch (tierForCountry(countryCode)) {
      case ArabicPricingTier.gcc:
        return gccVetAnchorEur;
      case ArabicPricingTier.standard:
        return standardVetAnchorEur;
      case ArabicPricingTier.emerging:
        return emergingVetAnchorEur;
    }
  }

  static double priceRatioForCountry(String? countryCode) =>
      vetAnchorEurForCountry(countryCode) / vetEuReferenceEur;

  static double adjustedEur(double baseEur, String? countryCode) {
    return (baseEur * priceRatioForCountry(countryCode) * 100).round() / 100;
  }

  static int adjustedScanCap(int euCap, String? countryCode) {
    final cap = (euCap * priceRatioForCountry(countryCode)).round();
    return cap < 3 ? 3 : cap;
  }

  /// Valuta prikaza za arapski jezik — po državi uređaja.
  static String currencyCodeForCountry(String? countryCode) {
    switch ((countryCode ?? 'SA').toUpperCase()) {
      case 'AE':
        return 'AED';
      case 'EG':
        return 'EGP';
      case 'MA':
        return 'MAD';
      case 'QA':
        return 'QAR';
      case 'JO':
        return 'JOD';
      case 'KW':
        return 'KWD';
      case 'OM':
        return 'OMR';
      case 'BH':
        return 'BHD';
      case 'SA':
      default:
        return 'SAR';
    }
  }
}
