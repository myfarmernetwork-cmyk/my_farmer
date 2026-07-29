import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/payment_service.dart';

class AppLocaleOption {
  final String languageCode;
  final String? countryCode;
  final String labelKey;

  const AppLocaleOption({
    required this.languageCode,
    this.countryCode,
    required this.labelKey,
  });

  Locale get locale => Locale(languageCode, countryCode ?? '');

  String get storageKey =>
      countryCode == null || countryCode!.isEmpty
          ? languageCode
          : '${languageCode}_$countryCode';

  /// Human-readable language name for pickers (never shows raw keys like lang_bs).
  String localizedLabel() {
    final primary = labelKey.tr();
    if (primary != labelKey) return primary;
    if (languageCode == 'bs') {
      const legacyKey = 'lang_hr_ba';
      final legacy = legacyKey.tr();
      if (legacy != legacyKey) return legacy;
      return 'Bosanski (BiH)';
    }
    return primary;
  }

  /// Flag shown in the profile language picker.
  String get flagEmoji {
    if (languageCode == 'sr' && countryCode == 'RS') return '🇷🇸';
    switch (languageCode) {
      case 'en':
        return '🇬🇧';
      case 'de':
        return '🇩🇪';
      case 'hr':
        return '🇭🇷';
      case 'bs':
        return '🇧🇦';
      case 'pl':
        return '🇵🇱';
      case 'sv':
        return '🇸🇪';
      case 'es':
        return '🇪🇸';
      case 'fr':
        return '🇫🇷';
      case 'cs':
        return '🇨🇿';
      case 'zh':
        return '🇨🇳';
      case 'uk':
        return '🇺🇦';
      case 'ru':
        return '🇷🇺';
      case 'hi':
        return '🇮🇳';
      case 'id':
        return '🇮🇩';
      case 'sw':
        return '🇰🇪';
      case 'ar':
        return '🇸🇦';
      case 'it':
        return '🇮🇹';
      case 'tr':
        return '🇹🇷';
      default:
        return '🌐';
    }
  }

  /// Maps legacy BiH locale keys to the single [bs] storage key.
  static String normalizeLegacyStorageKey(String? key) {
    if (key == null || key.isEmpty) return key ?? '';
    final normalized = key.contains('_')
        ? '${key.split('_').first}_${key.split('_').last.toUpperCase()}'
        : key.toLowerCase();
    switch (normalized) {
      case 'hr_BA':
      case 'sr_BA':
        return 'bs';
      default:
        return key.contains('_')
            ? '${key.split('_').first}_${key.split('_').last.toUpperCase()}'
            : key.toLowerCase();
    }
  }

  static AppLocaleOption? fromStorageKey(String? key) {
    if (key == null || key.isEmpty) return null;
    final resolved = normalizeLegacyStorageKey(key);
    for (final option in supportedAppLocales) {
      if (option.storageKey == resolved) return option;
    }
    final parts = resolved.split('_');
    if (parts.length == 1) {
      return AppLocaleOption(languageCode: parts[0], labelKey: 'lang_${parts[0]}');
    }
    return AppLocaleOption(
      languageCode: parts[0],
      countryCode: parts[1],
      labelKey: 'lang_${parts[0]}',
    );
  }

  static AppLocaleOption? fromLocale(Locale locale) {
    for (final option in supportedAppLocales) {
      if (option.languageCode == locale.languageCode &&
          (option.countryCode ?? '') == (locale.countryCode ?? '')) {
        return option;
      }
    }
    return AppLocaleOption(
      languageCode: locale.languageCode,
      countryCode: locale.countryCode,
      labelKey: 'lang_${locale.languageCode}',
    );
  }
}

const supportedAppLocales = [
  AppLocaleOption(languageCode: 'en', labelKey: 'lang_en'),
  AppLocaleOption(languageCode: 'de', labelKey: 'lang_de'),
  AppLocaleOption(languageCode: 'hr', countryCode: 'HR', labelKey: 'lang_hr'),
  AppLocaleOption(languageCode: 'bs', labelKey: 'lang_bs'),
  AppLocaleOption(languageCode: 'sr', countryCode: 'RS', labelKey: 'lang_sr'),
  AppLocaleOption(languageCode: 'pl', labelKey: 'lang_pl'),
  AppLocaleOption(languageCode: 'sv', labelKey: 'lang_sv'),
  AppLocaleOption(languageCode: 'es', labelKey: 'lang_es'),
  AppLocaleOption(languageCode: 'fr', labelKey: 'lang_fr'),
  AppLocaleOption(languageCode: 'cs', labelKey: 'lang_cs'),
  AppLocaleOption(languageCode: 'zh', labelKey: 'lang_zh'),
  AppLocaleOption(languageCode: 'uk', labelKey: 'lang_uk'),
  AppLocaleOption(languageCode: 'ru', labelKey: 'lang_ru'),
  AppLocaleOption(languageCode: 'hi', labelKey: 'lang_hi'),
  AppLocaleOption(languageCode: 'id', labelKey: 'lang_id'),
  AppLocaleOption(languageCode: 'sw', labelKey: 'lang_sw'),
  AppLocaleOption(languageCode: 'ar', labelKey: 'lang_ar'),
  AppLocaleOption(languageCode: 'it', labelKey: 'lang_it'),
  AppLocaleOption(languageCode: 'tr', labelKey: 'lang_tr'),
];

const supportedEasyLocales = [
  Locale('en'),
  Locale('de'),
  Locale('hr'),
  Locale('hr', 'HR'),
  Locale('bs'),
  Locale('sr'),
  Locale('sr', 'RS'),
  Locale('pl'),
  Locale('sv'),
  Locale('es'),
  Locale('fr'),
  Locale('cs'),
  Locale('zh'),
  Locale('uk'),
  Locale('ru'),
  Locale('hi'),
  Locale('id'),
  Locale('sw'),
  Locale('ar'),
  Locale('it'),
  Locale('tr'),
];

final currencyRegionProvider = StateProvider<String?>((ref) => null);

/// Valutna regija iz ISO države (GPS) — prioritet nad jezikom.
String regionFromCountryCode(String countryCode) {
  final code = countryCode.toUpperCase();
  if (code == 'BA') return 'bih';
  if (code == 'RS') return 'rs';
  if (code == 'SE') return 'se';
  if (PaymentService.isEuCountryCode(code)) return 'eu';
  if (PaymentService.isDevelopedCountryCode(code)) return 'eu';
  if (PaymentService.isEmergingMarketCountry(code)) return 'emerging';
  return 'eu';
}

/// GPS jednoznačno određuje valutu kad je poznata država.
/// BA/RS važe za sve jezike — Hrvat/Srbin u BiH plaća KM, ne €.
String? gpsLockedCurrencyRegion(String countryCode, String languageCode) {
  final code = countryCode.toUpperCase();
  if (code.isEmpty) return null;
  final lang = languageCode.toLowerCase();

  if (code == 'BA') return 'bih';
  if (code == 'RS') return 'rs';

  if (lang == 'hr') {
    if (code == 'HR' || PaymentService.isEuCountryCode(code)) return 'eu';
  }

  if (lang == 'sr' && PaymentService.isSerbiaCountryCode(code)) return 'rs';

  return null;
}

/// Jezici s ručnim biranjem valute u profilu (dijaspora — kad GPS nije BA/RS).
bool languageHasManualCurrencyPicker(String languageCode) {
  return languageCode == 'sr' || languageCode == 'sv';
}

/// Prioritet cijene/regije:
/// 1. **GPS** (verificirani)
/// 2. **IP geolokacija** (fizička lokacija bez GPS-a)
/// 3. **Država Play/App Store računa** (odakle se plaća)
/// 4. Ručni izbor u profilu (sr: BiH/Srbija, sv: SE/EU) — samo bez GPS/IP/uplate
/// 5. Jezik — zadnji fallback (EU/SE); **jezik ne smije dati jeftiniji paket**
///
/// Jezik određuje UI tekst; cijenu i limite određuju lokacija i store račun.
String? resolvePaymentCountryCode({String? fromProfile}) {
  final profile = (fromProfile ?? '').trim().toUpperCase();
  if (profile.isNotEmpty) return profile;
  return PaymentService.cachedPaymentCountryCode;
}

String _regionFromIsoCountry(
  String country,
  String lang,
  String stored,
) {
  if (country == 'BA') return 'bih';
  if (country == 'RS') return 'rs';

  final locked = gpsLockedCurrencyRegion(country, lang);
  if (locked != null) return locked;

  return regionFromCountryCode(country);
}

/// Država za naplatu — GPS → IP → store račun → ručni izbor (sr/sv). Jezik sam ne smije dati jeftiniji paket.
String? resolveBillingCountryCode({
  String? gpsCountry,
  String? ipCountry,
  String? paymentCountry,
  String? storedRegion,
  Locale? locale,
}) {
  final gps = (gpsCountry ?? '').toUpperCase();
  if (gps.isNotEmpty) return gps;

  final ip = (ipCountry ?? '').toUpperCase();
  if (ip.isNotEmpty) return ip;

  final payment = (paymentCountry ?? '').toUpperCase();
  if (payment.isNotEmpty) return payment;

  final stored = (storedRegion ?? '').toLowerCase();
  final lang = locale?.languageCode.toLowerCase() ?? '';

  if (lang == 'sr' && (stored == 'rs' || stored == 'bih')) {
    return stored == 'bih' ? 'BA' : 'RS';
  }
  if (lang == 'sv' && stored == 'se') return 'SE';

  return null;
}

String resolveCurrencyRegionForLocale(
  Locale locale, {
  String? storedRegion,
  String? deviceCountryCode,
  String? paymentCountryCode,
}) {
  final lang = locale.languageCode.toLowerCase();
  if (lang == 'zh') return 'cn';

  final billingCountry = (resolveBillingCountryCode(
        gpsCountry: PaymentService.cachedGpsVerifiedCountryCode,
        ipCountry: PaymentService.cachedIpCountryCode,
        paymentCountry: paymentCountryCode ??
            PaymentService.cachedPaymentCountryCode,
        storedRegion: storedRegion,
        locale: locale,
      ) ??
          deviceCountryCode ??
          '')
      .toUpperCase();
  final stored = (storedRegion ?? '').toLowerCase();

  if (billingCountry.isNotEmpty) {
    return _regionFromIsoCountry(billingCountry, lang, stored);
  }

  // Ručni izbor dijaspore kad nema GPS ni store države.
  if (lang == 'sr' && (stored == 'rs' || stored == 'bih')) return stored;
  if (lang == 'sv' && (stored == 'se' || stored == 'eu')) return stored;

  // Jezik — samo prikaz / zadnji fallback (nikad bs → bih bez lokacije ili uplate).
  if (lang == 'sv') return 'se';
  if (lang == 'hr') return 'eu';
  return 'eu';
}

/// Regije koje smiju biti u padajućem izboru (kad picker nije skriven).
List<String> allowedCurrencyRegionsForPicker(
  Locale locale, {
  String? deviceCountryCode,
  UserRole? role,
}) {
  final lang = locale.languageCode;
  if (lang == 'sr') return const ['rs', 'bih'];
  if (lang == 'sv' && role == UserRole.buyer) return const ['se', 'eu'];
  return const [];
}

/// Prikaži padajući izbor valutne regije — skriveno kad GPS zaključava valutu.
bool shouldShowCurrencyRegionPicker(
  Locale locale,
  UserRole role, {
  String? deviceCountryCode,
}) {
  final lang = locale.languageCode;
  if (lang == 'bs' || locale.countryCode == 'BA') return false;
  if (lang == 'hr') return false;

  final country = (deviceCountryCode ??
          PaymentService.cachedDeviceCountryCode ??
          '')
      .toUpperCase();
  if (gpsLockedCurrencyRegion(country, lang) != null) return false;

  if (lang == 'sr') return true;
  if (lang == 'sv') return role == UserRole.buyer;
  return false;
}

/// Valuta prema ulozi — veterinar na švedskom uvijek [se] (SEK).
String resolveCurrencyRegionForUser({
  required Locale locale,
  String? storedRegion,
  String? deviceCountryCode,
  String? paymentCountryCode,
  UserRole? role,
}) {
  if (locale.languageCode == 'sv' && role == UserRole.veterinarian) {
    return 'se';
  }
  return resolveCurrencyRegionForLocale(
    locale,
    storedRegion: storedRegion,
    deviceCountryCode: deviceCountryCode,
    paymentCountryCode: resolvePaymentCountryCode(
      fromProfile: paymentCountryCode,
    ),
  );
}

Future<void> applyLocaleSettings({
  required BuildContext context,
  required WidgetRef ref,
  required AppLocaleOption option,
  String? currencyRegion,
}) async {
  await context.setLocale(option.locale);
  final region = resolveCurrencyRegionForLocale(
    option.locale,
    storedRegion: currencyRegion ?? ref.read(currencyRegionProvider),
    deviceCountryCode: PaymentService.cachedGpsVerifiedCountryCode ??
        PaymentService.cachedDeviceCountryCode,
    paymentCountryCode: resolvePaymentCountryCode(),
  );
  ref.read(currencyRegionProvider.notifier).state = region;

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'preferredLanguage': option.storageKey,
        'currencyRegion': region,
        'languageCode': option.languageCode,
      },
      SetOptions(merge: true),
    );
  }
}

Future<void> loadUserLocaleSettings(WidgetRef ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  final data = doc.data();
  if (data == null) return;

  ref.read(currencyRegionProvider.notifier).state =
      data['currencyRegion'] as String?;
}
