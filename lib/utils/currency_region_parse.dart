import 'firestore_parse.dart';

/// Normalizes Firestore [currencyRegion] values for UI and pricing.
class CurrencyRegionParse {
  CurrencyRegionParse._();

  static const knownRegions = {
    'bih',
    'rs',
    'se',
    'eu',
    'emerging',
    'cn',
  };

  static String? normalize(dynamic value) {
    final raw = FirestoreParse.stringOrEmpty(value).toLowerCase();
    if (raw.isEmpty || raw == 'null') return null;

    switch (raw) {
      case 'ba':
      case 'bosnia':
      case 'bosna':
      case 'bih':
        return 'bih';
      case 'serbia':
      case 'srbija':
      case 'rs':
        return 'rs';
      case 'sweden':
      case 'se':
        return 'se';
      case 'eu':
      case 'europe':
      case 'eur':
        return 'eu';
      case 'cn':
      case 'china':
        return 'cn';
      case 'emerging':
        return 'emerging';
      default:
        if (knownRegions.contains(raw)) return raw;
        return null;
    }
  }

  static String orDefault(dynamic value, {String fallback = 'eu'}) {
    return normalize(value) ?? fallback;
  }

  static bool isKnown(String? region) {
    if (region == null || region.isEmpty) return false;
    return knownRegions.contains(region.toLowerCase());
  }
}
