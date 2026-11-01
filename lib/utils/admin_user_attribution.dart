import 'package:cloud_firestore/cloud_firestore.dart';

/// Zemlja / jezik za admin statistiku (Firestore polja na `users`).
class AdminUserAttribution {
  AdminUserAttribution._();

  static String? countryCodeFromUser(Map<String, dynamic> data) {
    for (final key in [
      'signupCountryCode',
      'lastSeenCountryCode',
      'paymentCountryCode',
      'signupIpCountryCode',
      'lastSeenIpCountryCode',
    ]) {
      final raw = data[key]?.toString().trim().toUpperCase();
      if (raw != null && raw.length == 2) return raw;
    }
    return null;
  }

  static String countryLabel(String? iso2) {
    if (iso2 == null || iso2.isEmpty) return 'Nepoznato';
    switch (iso2.toUpperCase()) {
      case 'DE':
        return 'Njemačka (DE)';
      case 'BA':
        return 'BiH (BA)';
      case 'HR':
        return 'Hrvatska (HR)';
      case 'RS':
        return 'Srbija (RS)';
      case 'AT':
        return 'Austrija (AT)';
      case 'CH':
        return 'Švicarska (CH)';
      case 'SI':
        return 'Slovenija (SI)';
      case 'US':
        return 'SAD (US)';
      case 'GB':
        return 'UK (GB)';
      case 'FR':
        return 'Francuska (FR)';
      case 'IT':
        return 'Italija (IT)';
      case 'PL':
        return 'Poljska (PL)';
      case 'NL':
        return 'Nizozemska (NL)';
      case 'SE':
        return 'Švedska (SE)';
      case 'TR':
        return 'Turska (TR)';
      default:
        return iso2.toUpperCase();
    }
  }

  static String localeLabel(Map<String, dynamic> data) {
    final signup = data['signupLocale']?.toString().trim();
    if (signup != null && signup.isNotEmpty) return signup;
    final last = data['lastSeenLocale']?.toString().trim();
    if (last != null && last.isNotEmpty) return last;
    final pref = data['preferredLanguage']?.toString().trim();
    if (pref != null && pref.isNotEmpty) return pref;
    return '—';
  }

  static String platformLabel(Map<String, dynamic> data) {
    final p = data['signupPlatform']?.toString() ??
        data['lastSeenPlatform']?.toString() ??
        '—';
    switch (p.toLowerCase()) {
      case 'android':
        return 'Android (Play)';
      case 'ios':
        return 'iOS (App Store)';
      default:
        return p;
    }
  }

  static String signupVersion(Map<String, dynamic> data) {
    return data['signupAppVersion']?.toString().trim() ??
        data['lastSeenAppVersion']?.toString().trim() ??
        '—';
  }

  /// Jedna linija za listu korisnika.
  static String listSubtitleLine(Map<String, dynamic> data) {
    final cc = countryCodeFromUser(data);
    final country = countryLabel(cc);
    final locale = localeLabel(data);
    return 'Zemlja: $country · Jezik: $locale';
  }

  /// Agregat registracija po zemlji (signup, pa fallback lastSeen).
  static List<AdminCountryCount> countsByCountry(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final counts = <String, int>{};
    for (final doc in docs) {
      final code = countryCodeFromUser(doc.data()) ?? '??';
      counts[code] = (counts[code] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map(
          (e) => AdminCountryCount(
            countryCode: e.key,
            label: countryLabel(e.key == '??' ? null : e.key),
            count: e.value,
          ),
        )
        .toList();
  }
}

class AdminCountryCount {
  const AdminCountryCount({
    required this.countryCode,
    required this.label,
    required this.count,
  });

  final String countryCode;
  final String label;
  final int count;
}
