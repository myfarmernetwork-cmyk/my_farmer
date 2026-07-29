// Naplata u košarici (Stripe / PayPal / keš) i poslovni model pretplata.
//
// Poslovna pretplata tvrtke — cijena prati STVARNU REGIJU UREĐAJA (GPS → sustav → IP),
// ne ručno odabrani jezik. Minimalni prag 4,99 €/mj (No-Loss AI Shield).
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../config/arabic_market_pricing.dart';
import '../config/swiss_market_pricing.dart';
import '../config/turkey_market_pricing.dart';
import '../config/payment_config.dart';
import '../config/revenuecat_config.dart';
import '../config/subscription_limits.dart';
import '../models/payment_method.dart';
import '../models/subscription_tier.dart';
import '../models/app_user.dart';
import '../models/payment_result.dart';
import 'currency_service.dart';
import 'delivery_service.dart';
import 'paypal_checkout_service.dart';
import 'product_upload_service.dart';
import 'stripe_checkout_service.dart';

/// Izvor detekcije države uređaja (prioritet: GPS → sustav/SIM → IP).
enum DeviceRegionSource {
  gps,
  systemLocale,
  ip,
  fallback,
}

/// Regionalna zona poslovne pretplate tvrtke.
enum BusinessPricingZone {
  eu,
  bih,
  serbia,
  developed,
  emerging,
}

/// Zahtjev za regionalnu cijenu firme — jezik + valutna regija (GPS/profil).
class CompanyQuoteRequest {
  const CompanyQuoteRequest({
    required this.languageCode,
    this.currencyRegion,
  });

  final String languageCode;
  final String? currencyRegion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyQuoteRequest &&
          other.languageCode == languageCode &&
          other.currencyRegion == currencyRegion;

  @override
  int get hashCode => Object.hash(languageCode, currencyRegion);
}

/// Dinamička ponuda poslovne pretplate prema regiji uređaja.
class CompanySubscriptionQuote {
  const CompanySubscriptionQuote({
    required this.countryCode,
    required this.zone,
    required this.amount,
    required this.currencyCode,
    required this.amountEurEquivalent,
    required this.source,
    required this.priceLine,
    required this.activateButtonLabel,
  });

  final String countryCode;
  final BusinessPricingZone zone;
  final double amount;
  final String currencyCode;
  final double amountEurEquivalent;
  final DeviceRegionSource source;
  final String priceLine;
  final String activateButtonLabel;
}

class PaymentService {
  PaymentService({
    StripeCheckoutService? stripeCheckoutService,
    PayPalCheckoutService? paypalCheckoutService,
  })  : _stripeCheckoutService =
            stripeCheckoutService ?? StripeCheckoutService(),
        _paypalCheckoutService =
            paypalCheckoutService ?? PayPalCheckoutService();

  final StripeCheckoutService _stripeCheckoutService;
  final PayPalCheckoutService _paypalCheckoutService;

  static const double companyEuMonthlyEur = 19.99;
  static const double companyBihMonthlyKm = 19.99;
  static const double companySerbiaMonthlyRsd = 1199;
  static const double vetSerbiaMonthlyRsd = 599;
  static const double aiNoLossFloorEur = 4.99;

  /// Plant.id (~0,10 €/scan) + vaša marža 0,05 € po dokupu.
  static const double scanApiCostEur = 0.10;
  static const double scanTopUpProfitEur = 0.05;
  static const double scanTopUpUnitPriceEur =
      scanApiCostEur + scanTopUpProfitEur;

  /// Dinamički mjesečni limit AI skenova za firmu — usklađen s cijenom regije.
  /// EU/razvijeno (19,99 €): 100 · Balkan (19,99 KM): 50 · Ostalo/min: 25.
  static const int companyScanCapEu = 100;
  static const int companyScanCapBalkan = 50;
  static const int companyScanCapEmerging = 25;

  /// Admin računi — besplatan pristup svim premium alatima (bez paywalla).
  static bool hasAdminPremiumBypass(
    AppUser? user, {
    String? resolvedFirestoreRole,
  }) {
    if (AppUser.normalizeRoleAlias(resolvedFirestoreRole) == 'admin') {
      return true;
    }
    if (user == null) return false;
    if (user.isAdminUser) return true;
    return hasAdminBypassEmail(user.email);
  }

  /// Poznati admin e-mailovi (fallback ako Firestore nema role/isAdmin).
  static bool hasAdminBypassEmail(String? email) {
    final normalized = email?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return false;
    return _adminBypassEmails.contains(normalized);
  }

  static const Set<String> _adminBypassEmails = {'myfarmer.network@gmail.com'};

  /// Maks. skenova/mj. za poslovnu pretplatu prema regiji (GPS → sustav → IP).
  static Future<int> resolveCompanyMonthlyScanCap({
    required String languageCode,
  }) async {
    final device = await resolveDeviceCountry();
    return companyMonthlyScanCapForCountry(
      device.countryCode,
      languageCode: languageCode,
    );
  }

  static int companyMonthlyScanCapForCountry(
    String countryCode, {
    required String languageCode,
  }) {
    final billingCountry = countryCode.toUpperCase();
    if (billingCountry == 'TR') {
      return TurkeyMarketPricing.adjustedScanCap(companyScanCapEu);
    }
    if (billingCountry == 'IN' || billingCountry == 'ID') {
      return emergingAsiaAdjustedScanCap(companyScanCapEu);
    }
    if (billingCountry == 'KE') {
      return kenyaAdjustedScanCap(companyScanCapEu);
    }
    if (ArabicMarketPricing.arabCountries.contains(billingCountry)) {
      return ArabicMarketPricing.adjustedScanCap(
        companyScanCapEu,
        billingCountry,
      );
    }

    final zone = zoneForCountry(billingCountry, languageCode: languageCode);
    switch (zone) {
      case BusinessPricingZone.eu:
      case BusinessPricingZone.developed:
        return companyScanCapEu;
      case BusinessPricingZone.bih:
      case BusinessPricingZone.serbia:
        return companyScanCapBalkan;
      case BusinessPricingZone.emerging:
        return companyScanCapEmerging;
    }
  }

  /// Sync limit skenova za firmu — prikaz u paywallu / skeneru.
  static int companyMonthlyScanCapForDisplay({
    required String languageCode,
    String? countryCode,
    String? currencyRegion,
  }) {
    final code = _resolveCompanyCountryCode(
      countryCode: countryCode,
      currencyRegion: currencyRegion,
      languageCode: languageCode,
    );
    return companyMonthlyScanCapForCountry(code, languageCode: languageCode);
  }

  static String _resolveCompanyCountryCode({
    String? countryCode,
    String? currencyRegion,
    required String languageCode,
  }) {
    return _resolvePricingCountryCode(
      countryCode: countryCode ?? cachedDeviceCountryCode,
      currencyRegion: companyCurrencyRegion(
        languageCode: languageCode,
        currencyRegion: currencyRegion,
        deviceCountryCode: countryCode ?? cachedDeviceCountryCode,
      ),
      languageCode: languageCode,
    );
  }

  /// Valutna regija firme — koristi već izračunatu regiju iz [resolveCurrencyRegionForUser].
  static String companyCurrencyRegion({
    required String languageCode,
    required String? currencyRegion,
    String? deviceCountryCode,
  }) {
    final resolved = (currencyRegion ?? '').toLowerCase();
    if (resolved.isNotEmpty) return resolved;

    final country =
        (deviceCountryCode ?? cachedDeviceCountryCode ?? '').toUpperCase();
    if (country.isNotEmpty) {
      final zone = zoneForCountry(country, languageCode: languageCode);
      switch (zone) {
        case BusinessPricingZone.bih:
          return 'bih';
        case BusinessPricingZone.serbia:
          return 'rs';
        case BusinessPricingZone.emerging:
          return 'emerging';
        case BusinessPricingZone.eu:
        case BusinessPricingZone.developed:
          return 'eu';
      }
    }

    return _defaultVetCurrencyRegionForLanguage(
      languageCode,
      countryCode: country,
    );
  }

  /// Mjesečna cijena poslovne pretplate — regija (GPS/profil) nadjačava jezik.
  static String companyPriceLine({
    required String languageCode,
    required String? currencyRegion,
  }) {
    final countryCode = _resolveCompanyCountryCode(
      currencyRegion: currencyRegion,
      languageCode: languageCode,
    );
    return quoteForCountry(countryCode, languageCode: languageCode).priceLine;
  }

  /// Gumb poslovne pretplate — dinamička cijena po regiji, tekst po jeziku.
  static String companySubscribeButtonLabel({
    required String languageCode,
    required String? currencyRegion,
  }) {
    final priceLine = companyPriceLine(
      languageCode: languageCode,
      currencyRegion: currencyRegion,
    );
    return _formatActivateButtonLabel(
      languageCode: languageCode,
      priceLine: priceLine,
    );
  }

  static String companyScannerBenefitLine({
    required String languageCode,
    String? countryCode,
    String? currencyRegion,
  }) {
    final count = companyMonthlyScanCapForDisplay(
      languageCode: languageCode,
      countryCode: countryCode,
      currencyRegion: currencyRegion,
    );
    final lang = _normalizeLanguage(languageCode);
    switch (lang) {
      case 'de':
        return 'KI-Pflanzenscanner — $count Scans pro Monat';
      case 'en':
        return 'AI Plant Scanner — $count scans per month';
      case 'es':
        return 'Escáner IA de plantas — $count escaneos al mes';
      case 'fr':
        return 'Scanner IA des plantes — $count scans par mois';
      case 'it':
        return 'Scanner IA delle piante — $count scansioni al mese';
      case 'cs':
        return 'AI skener rostlin — $count skenů měsíčně';
      case 'sr':
        return 'AI Skener biljaka — $count skeniranja mesečno';
      case 'sv':
        return 'AI-växtskanner — $count skanningar per månad';
      case 'pl':
        return 'Skaner AI roślin — $count skanów miesięcznie';
      case 'zh':
        return 'AI 植物扫描 — 每月 $count 次';
      case 'uk':
        return 'ШІ-сканер рослин — $count сканувань на місяць';
      case 'ru':
        return 'ИИ-сканер растений — $count сканирований в месяц';
      case 'hi':
        return 'AI पौधा स्कैनर — प्रति माह $count स्कैन';
      case 'id':
        return 'Pemindai AI Tanaman — $count pemindaian per bulan';
      case 'sw':
        return 'AI Kichanganuzi cha Mimea — skani $count kwa mwezi';
      case 'ar':
        return 'ماسح AI للنباتات — $count عملية مسح/الشهر';
      case 'tr':
        return 'AI Bitki Tarayıcı — ayda $count tarama';
      default:
        return 'AI Skener biljaka — $count skeniranja mjesečno';
    }
  }

  /// Zamijeni `{count}` u prevodu stvarnim mjesečnim limitom firme za regiju.
  static String applyCompanyScanCountTemplate(
    String template, {
    required String languageCode,
    String? countryCode,
    String? currencyRegion,
  }) {
    if (!template.contains('{count}')) return template;
    final count = companyMonthlyScanCapForDisplay(
      languageCode: languageCode,
      countryCode: countryCode,
      currencyRegion: currencyRegion,
    );
    return template.replaceAll('{count}', '$count');
  }

  /// Fiksni prikaz za domaće balkansko tržište — bez EUR konverzije.
  static const String bihFlatPriceDisplay = '19,99 KM';
  static const String serbiaFlatPriceDisplay = '1.199 RSD';
  static const String vetSerbiaFlatPriceDisplay = '599 RSD';
  static const String balkanBuyerKmDisplay = '1,99 KM';
  static const String balkanBuyerRsdDisplay = '199 RSD';
  static const String balkanHobbyKmDisplay = '3,99 KM';
  static const String balkanHobbyRsdDisplay = '399 RSD';
  static const String balkanPremiumKmDisplay = '9,99 KM';
  static const String balkanPremiumRsdDisplay = '599 RSD';

  static const double eurToUsd = 1.08;
  static const double eurToGbp = 0.86;
  static const double eurToInr = 92.0;

  static String? _cachedCountryCode;
  static DeviceRegionSource? _cachedSource;
  static String? _cachedPaymentCountryCode;
  static String? _cachedPricingIpCountryCode;

  /// Zadnja poznata država uređaja (GPS → sustav → IP) — sync pristup.
  static String? get cachedDeviceCountryCode => _cachedCountryCode;

  /// Država Play/App Store računa (RevenueCat storefront) — odakle se plaća.
  static String? get cachedPaymentCountryCode => _cachedPaymentCountryCode;

  /// Samo GPS-verificirana država — IP/sistem/fallback DE se ne koriste za cijenu.
  static String? get cachedGpsVerifiedCountryCode {
    if (_cachedSource == DeviceRegionSource.gps &&
        _cachedCountryCode != null &&
        _cachedCountryCode!.isNotEmpty) {
      return _cachedCountryCode!.toUpperCase();
    }
    return null;
  }

  /// Država preko IP geolokacije (bez GPS-a).
  static String? get cachedIpCountryCode {
    final pricingIp = _cachedPricingIpCountryCode;
    if (pricingIp != null && pricingIp.isNotEmpty) {
      return pricingIp.toUpperCase();
    }
    if (_cachedSource == DeviceRegionSource.ip &&
        _cachedCountryCode != null &&
        _cachedCountryCode!.isNotEmpty) {
      return _cachedCountryCode!.toUpperCase();
    }
    return null;
  }

  /// Fizička lokacija za naplatu: GPS → IP → store račun (zadnji fallback).
  static String? resolveBillingCountryForPricing({
    String? paymentCountryCode,
  }) {
    final gps = cachedGpsVerifiedCountryCode;
    if (gps != null && gps.isNotEmpty) return gps;

    final ip = cachedIpCountryCode;
    if (ip != null && ip.isNotEmpty) return ip;

    final payment =
        (paymentCountryCode ?? cachedPaymentCountryCode ?? '').trim().toUpperCase();
    if (payment.isNotEmpty) return payment;

    return null;
  }

  static void cachePaymentCountryCode(String? countryCode) {
    if (countryCode == null || countryCode.trim().isEmpty) {
      _cachedPaymentCountryCode = null;
      return;
    }
    _cachedPaymentCountryCode = countryCode.trim().toUpperCase();
  }

  static bool isEuCountryCode(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return false;
    return _euCountryCodes.contains(countryCode.toUpperCase());
  }

  static bool isSerbiaCountryCode(String? countryCode) {
    return countryCode?.toUpperCase() == 'RS';
  }

  static bool isSwedenCountryCode(String? countryCode) {
    return countryCode?.toUpperCase() == 'SE';
  }

  /// Jedinstvena kanonska cijena u EUR (EU razina).
  static double get companySubscriptionMonthlyEur =>
      ProductUploadService.companySubscriptionMonthlyEur;

  static String get companySubscriptionProductId =>
      RevenueCatConfig.licensePharmacyMonthly;

  static String displayCurrencyCodeForLocale(Locale locale) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'zh') {
      return CurrencyService.cny;
    }
    return CurrencyService().resolveBuyerCurrencyCode(locale);
  }

  /// Dohvat stvarne regije uređaja — GPS, zatim sustav/SIM, zatim IP.
  static Future<({String countryCode, DeviceRegionSource source})>
      resolveDeviceCountry() async {
    if (_cachedCountryCode != null && _cachedSource != null) {
      return (countryCode: _cachedCountryCode!, source: _cachedSource!);
    }

    final gpsCountry = await _countryFromGps();
    if (gpsCountry != null) {
      _cacheCountry(gpsCountry, DeviceRegionSource.gps);
      return (countryCode: gpsCountry, source: DeviceRegionSource.gps);
    }

    final ipCountry = await _countryFromIp();
    if (ipCountry != null) {
      _cachedPricingIpCountryCode = ipCountry.toUpperCase();
      _cacheCountry(ipCountry, DeviceRegionSource.ip);
      return (countryCode: ipCountry, source: DeviceRegionSource.ip);
    }

    final systemCountry = _countryFromSystemLocale();
    if (systemCountry != null) {
      _cacheCountry(systemCountry, DeviceRegionSource.systemLocale);
      return (
        countryCode: systemCountry,
        source: DeviceRegionSource.systemLocale,
      );
    }

    _cacheCountry('DE', DeviceRegionSource.fallback);
    return (countryCode: 'DE', source: DeviceRegionSource.fallback);
  }

  static void _cacheCountry(String code, DeviceRegionSource source) {
    _cachedCountryCode = code.toUpperCase();
    _cachedSource = source;
    CurrencyService.cacheDeviceCountryCode(_cachedCountryCode);
  }

  static void clearCountryCache() {
    _cachedCountryCode = null;
    _cachedSource = null;
    _cachedPaymentCountryCode = null;
    _cachedPricingIpCountryCode = null;
    CurrencyService.cacheDeviceCountryCode(null);
  }

  /// Vraća GPS državu iz lokalne pohrane (npr. nakon hot restarta).
  static void restoreGpsCountry(String countryCode) {
    if (countryCode.trim().isEmpty) return;
    _cacheCountry(countryCode.trim().toUpperCase(), DeviceRegionSource.gps);
  }

  static String _resolveArabCountryCode({String? countryCode}) {
    final code = (countryCode ?? cachedDeviceCountryCode ?? 'SA').toUpperCase();
    if (ArabicMarketPricing.arabCountries.contains(code)) return code;
    return 'SA';
  }

  static bool isSwissDeFrPricingContext({
    String? languageCode,
    String? countryCode,
  }) {
    return SwissMarketPricing.isSwissDeFrContext(
      languageCode: languageCode,
      countryCode: countryCode ?? cachedDeviceCountryCode,
    );
  }

  static bool get hasGpsVerifiedLocation =>
      _cachedSource == DeviceRegionSource.gps &&
      _cachedCountryCode != null &&
      _cachedCountryCode!.isNotEmpty;

  static bool isDevelopedCountryCode(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return false;
    return _developedCountryCodes.contains(countryCode.toUpperCase());
  }

  static bool isEmergingMarketCountry(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return false;
    final code = countryCode.toUpperCase();
    return _africaCountryCodes.contains(code) ||
        _southAsiaCountryCodes.contains(code) ||
        _southeastAsiaCountryCodes.contains(code) ||
        _latinAmericaCountryCodes.contains(code);
  }

  /// Samo GPS — za cijene pretplata (bez IP/sistem fallbacka).
  static Future<({String countryCode, DeviceRegionSource source})?>
      resolveDeviceCountryForPricing() async {
    final gpsCountry = await _countryFromGps();
    if (gpsCountry == null) return null;
    _cacheCountry(gpsCountry, DeviceRegionSource.gps);
    return (countryCode: gpsCountry, source: DeviceRegionSource.gps);
  }

  static Future<String?> _countryFromGps() async {
    try {
      final delivery = DeliveryService();
      final position = await delivery.getCurrentPosition();
      if (position == null) return null;

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final code = placemarks.first.isoCountryCode?.toUpperCase();
          if (code != null && code.length == 2) return code;
        }
      } catch (_) {}

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${position.latitude}&lon=${position.longitude}&format=json',
      );
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'MyFarmerApp/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      final code = (address?['country_code'] as String?)?.toUpperCase();
      if (code == null || code.length != 2) return null;
      return code;
    } catch (_) {
      return null;
    }
  }

  static String? _countryFromSystemLocale() {
    final code = ui.PlatformDispatcher.instance.locale.countryCode;
    if (code == null || code.length != 2) return null;
    return code.toUpperCase();
  }

  static Future<String?> _countryFromIp() async {
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json/?fields=countryCode'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final code = (data['countryCode'] as String?)?.toUpperCase();
      if (code == null || code.length != 2) return null;
      return code;
    } catch (_) {
      return null;
    }
  }

  static BusinessPricingZone zoneForCountry(
    String countryCode, {
    String? languageCode,
  }) {
    final code = countryCode.toUpperCase();

    // Cijena pretplate prati ISKLJUČIVO GPS državu — ne jezik.
    if (code == 'BA') return BusinessPricingZone.bih;
    if (code == 'RS') return BusinessPricingZone.serbia;
    if (_euCountryCodes.contains(code)) return BusinessPricingZone.eu;
    if (_developedCountryCodes.contains(code)) {
      return BusinessPricingZone.developed;
    }
    if (isEmergingMarketCountry(code)) return BusinessPricingZone.emerging;
    return BusinessPricingZone.eu;
  }

  static bool _isBihMarket({required String code, required String languageTag}) {
    if (code == 'BA') return true;
    if (languageTag == 'bs') return true;
    return false;
  }

  static bool _isSerbiaMarket({required String code, required String languageTag}) {
    if (code == 'BA') return false;
    if (languageTag == 'bs') return false;
    if (code == 'RS') return true;
    if (languageTag == 'sr-rs') return true;
    if (languageTag == 'sr') return true;
    return false;
  }

  static String _normalizeLanguageTag(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return '';
    return languageCode.toLowerCase().replaceAll('_', '-');
  }

  static bool _isEuroLockedLanguageCode(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return false;
    final lang = languageCode.toLowerCase().split('-').first.split('_').first;
    return lang == 'hr' || lang == 'de' || lang == 'pl' || lang == 'es' || lang == 'fr' || lang == 'cs';
  }

  static bool _isSekLockedLanguageCode(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return false;
    return languageCode.toLowerCase().split('-').first.split('_').first == 'sv';
  }

  static bool _isUahLockedLanguageCode(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return false;
    return languageCode.toLowerCase().split('-').first.split('_').first == 'uk';
  }

  static bool _isRubLockedLanguageCode(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return false;
    return languageCode.toLowerCase().split('-').first.split('_').first == 'ru';
  }

  static bool _isInrLockedLanguageCode(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return false;
    return languageCode.toLowerCase().split('-').first.split('_').first == 'hi';
  }

  static bool _isIdrLockedLanguageCode(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return false;
    return languageCode.toLowerCase().split('-').first.split('_').first == 'id';
  }

  static bool _isKesLockedLanguageCode(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return false;
    return languageCode.toLowerCase().split('-').first.split('_').first == 'sw';
  }

  static bool _isArabicLockedLanguageCode(String? languageCode) {
    return ArabicMarketPricing.isArabicLanguage(languageCode);
  }

  static bool _isTryLockedLanguageCode(String? languageCode) {
    return TurkeyMarketPricing.isTurkishLanguage(languageCode);
  }

  /// Mjesečna cijena paketa u EUR prema GPS zoni (ne jeziku).
  static double? monthlyTierEurForCountry(
    String countryCode,
    String productId,
  ) {
    final base = RevenueCatConfig.monthlyPriceEurForProductId(productId);
    if (base == null) return null;

    if (countryCode.toUpperCase() == 'IN' || countryCode.toUpperCase() == 'ID') {
      return emergingAsiaAdjustedEur(base);
    }
    if (countryCode.toUpperCase() == 'KE') {
      return kenyaAdjustedEur(base);
    }
    if (countryCode.toUpperCase() == 'TR') {
      return TurkeyMarketPricing.adjustedEur(base);
    }
    if (ArabicMarketPricing.arabCountries.contains(countryCode.toUpperCase())) {
      return ArabicMarketPricing.adjustedEur(base, countryCode);
    }

    final zone = zoneForCountry(countryCode);
    switch (zone) {
      case BusinessPricingZone.bih:
      case BusinessPricingZone.serbia:
        return _balkanMonthlyEurForProduct(productId);
      case BusinessPricingZone.eu:
      case BusinessPricingZone.developed:
        if (productId == RevenueCatConfig.licensePharmacyMonthly) {
          return companyEuMonthlyEur;
        }
        return base;
      case BusinessPricingZone.emerging:
        if (productId == RevenueCatConfig.licensePharmacyMonthly) {
          return _emergingTierEur(companyEuMonthlyEur, countryCode);
        }
        return _emergingTierEur(base, countryCode);
    }
  }

  /// Mjesečna cijena paketa u EUR prema jeziku (Kenya / arapski po tieru).
  static double? monthlyTierEurForLanguage(
    String? languageCode,
    String productId,
  ) {
    final base = RevenueCatConfig.monthlyPriceEurForProductId(productId);
    if (base == null) return null;
    if (_isInrLockedLanguageCode(languageCode) ||
        _isIdrLockedLanguageCode(languageCode)) {
      return emergingAsiaAdjustedEur(base);
    }
    if (_isArabicLockedLanguageCode(languageCode)) {
      final arabCountry = _resolveArabCountryCode();
      if (productId == RevenueCatConfig.licensePharmacyMonthly) {
        return ArabicMarketPricing.adjustedEur(companyEuMonthlyEur, arabCountry);
      }
      return ArabicMarketPricing.adjustedEur(base, arabCountry);
    }
    if (isSwissDeFrPricingContext(languageCode: languageCode)) {
      if (productId == RevenueCatConfig.licensePharmacyMonthly) {
        return SwissMarketPricing.adjustedEur(companyEuMonthlyEur);
      }
      return SwissMarketPricing.adjustedEur(base);
    }
    if (_isKesLockedLanguageCode(languageCode)) {
      if (productId == RevenueCatConfig.licensePharmacyMonthly) {
        return kenyaAdjustedEur(companyEuMonthlyEur);
      }
      return kenyaAdjustedEur(base);
    }
    if (_isTryLockedLanguageCode(languageCode)) {
      if (productId == RevenueCatConfig.licensePharmacyMonthly) {
        return TurkeyMarketPricing.adjustedEur(companyEuMonthlyEur);
      }
      return TurkeyMarketPricing.adjustedEur(base);
    }
    return base;
  }

  /// Lokalizirani redak cijene pretplate — prati GPS državu / ručnu regiju (sr).
  static String? subscriptionPriceLineForProduct({
    required String productId,
    required String languageCode,
    String? countryCode,
    String? currencyRegion,
    String? paymentCountryCode,
  }) {
    final billingCountry = (countryCode ??
            resolveBillingCountryForPricing(
              paymentCountryCode: paymentCountryCode,
            ) ??
            '')
        .toUpperCase();

    if (isSwissDeFrPricingContext(
      languageCode: languageCode,
      countryCode: billingCountry.isNotEmpty ? billingCountry : countryCode,
    )) {
      final base = RevenueCatConfig.monthlyPriceEurForProductId(productId);
      if (base == null) return null;
      return _formatMonthlyPriceLine(
        amount: SwissMarketPricing.chfAmount(base),
        currencyCode: CurrencyService.chf,
        languageCode: languageCode,
      );
    }

    final code = billingCountry.isNotEmpty
        ? billingCountry
        : _resolvePricingCountryCode(
            countryCode: countryCode,
            currencyRegion: currencyRegion,
            languageCode: languageCode,
          );
    final eur = monthlyTierEurForCountry(code, productId);
    if (eur == null) return null;

    final zone = zoneForCountry(code);
    final balkanLine = _balkanFlatPriceLineForProduct(
      productId: productId,
      zone: zone,
      languageCode: languageCode,
    );
    if (balkanLine != null) return balkanLine;

    final currencyCode = CurrencyService().currencyCodeFromCountry(code);
    final amount = currencyCode == CurrencyService.eur
        ? eur
        : _convertFromEur(eur, currencyCode);
    return _formatMonthlyPriceLine(
      amount: amount,
      currencyCode: currencyCode,
      languageCode: languageCode,
    );
  }

  static const double vetEuMonthlyEur = 9.99;
  static const double vetBihMonthlyKm = 9.99;
  static const String vetBihFlatPriceDisplay = '9,99 KM';

  /// Indija (hi/IN) i Indonezija (id/ID): sidro 3,00 € umjesto 9,99 € — ista proporcija i za skenove.
  static const double emergingAsiaPremiumMonthlyEur = 3.0;
  static const double emergingAsiaPriceRatio =
      emergingAsiaPremiumMonthlyEur / vetEuMonthlyEur;

  static bool isEmergingAsiaPricingContext({
    String? languageCode,
    String? countryCode,
  }) {
    final code = (countryCode ??
            cachedGpsVerifiedCountryCode ??
            cachedIpCountryCode ??
            '')
        .toUpperCase();
    return code == 'IN' || code == 'ID';
  }

  static double emergingAsiaAdjustedEur(double baseEur) {
    return (baseEur * emergingAsiaPriceRatio * 100).round() / 100;
  }

  static int emergingAsiaAdjustedScanCap(int euCap) {
    final cap = (euCap * emergingAsiaPriceRatio).round();
    return cap < 3 ? 3 : cap;
  }

  /// Kenya (Kiswahili / KE): sidro 2,99 € umjesto 9,99 € — ista proporcija i za skenove.
  static const double kenyaPremiumMonthlyEur = 2.99;
  static const double kenyaPriceRatio =
      kenyaPremiumMonthlyEur / vetEuMonthlyEur;

  static bool isKenyaPricingContext({
    String? languageCode,
    String? countryCode,
  }) {
    final code = (countryCode ??
            cachedGpsVerifiedCountryCode ??
            cachedIpCountryCode ??
            '')
        .toUpperCase();
    return code == 'KE';
  }

  static double kenyaAdjustedEur(double baseEur) {
    return (baseEur * kenyaPriceRatio * 100).round() / 100;
  }

  static int kenyaAdjustedScanCap(int euCap) {
    final cap = (euCap * kenyaPriceRatio).round();
    return cap < 3 ? 3 : cap;
  }

  static bool isTurkeyPricingContext({
    String? languageCode,
    String? countryCode,
  }) {
    return TurkeyMarketPricing.isTurkeyPricingContext(
      languageCode: languageCode,
      countryCode: countryCode ?? cachedDeviceCountryCode,
    );
  }

  static int turkeyAdjustedScanCap(int euCap) {
    return TurkeyMarketPricing.adjustedScanCap(euCap);
  }

  static double turkeyAdjustedEur(double baseEur) {
    return TurkeyMarketPricing.adjustedEur(baseEur);
  }

  static double _emergingTierEur(double baseEur, String countryCode) {
    if (countryCode.toUpperCase() == 'KE') {
      return kenyaAdjustedEur(baseEur);
    }
    var eur = baseEur * _pppFactorForCountry(countryCode);
    if (eur < aiNoLossFloorEur) {
      eur = aiNoLossFloorEur;
    }
    return (eur * 100).round() / 100;
  }

  /// Mjesečni limit AI skenova za veterinara — Balkan jeftiniji paket, EU više skenova.
  static const int vetScanCapBalkan = 25;
  static const int vetScanCapEu = 50;

  static int resolveVetMonthlyScanCap({
    required String? currencyRegion,
    String? languageCode,
    String? countryCode,
  }) {
    final billingCountry = (countryCode ??
            resolveBillingCountryForPricing() ??
            '')
        .toUpperCase();
    if (billingCountry.isNotEmpty) {
      if (billingCountry == 'TR') {
        return turkeyAdjustedScanCap(vetScanCapEu);
      }
      if (billingCountry == 'IN' || billingCountry == 'ID') {
        return emergingAsiaAdjustedScanCap(vetScanCapEu);
      }
      if (billingCountry == 'KE') {
        return kenyaAdjustedScanCap(vetScanCapEu);
      }
      if (ArabicMarketPricing.arabCountries.contains(billingCountry)) {
        return ArabicMarketPricing.adjustedScanCap(
          vetScanCapEu,
          billingCountry,
        );
      }

      final zone = zoneForCountry(billingCountry, languageCode: languageCode);
      switch (zone) {
        case BusinessPricingZone.bih:
        case BusinessPricingZone.serbia:
          return vetScanCapBalkan;
        case BusinessPricingZone.eu:
        case BusinessPricingZone.developed:
        case BusinessPricingZone.emerging:
          return vetScanCapEu;
      }
    }

    if (isEmergingAsiaPricingContext(
      languageCode: languageCode,
      countryCode: countryCode,
    )) {
      return emergingAsiaAdjustedScanCap(vetScanCapEu);
    }
    if (isKenyaPricingContext(
      languageCode: languageCode,
      countryCode: countryCode,
    )) {
      return kenyaAdjustedScanCap(vetScanCapEu);
    }
    if (isTurkeyPricingContext(
      languageCode: languageCode,
      countryCode: countryCode,
    )) {
      return turkeyAdjustedScanCap(vetScanCapEu);
    }
    if (ArabicMarketPricing.isArabicPricingContext(
      languageCode: languageCode,
      countryCode: countryCode,
    )) {
      return ArabicMarketPricing.adjustedScanCap(
        vetScanCapEu,
        _resolveArabCountryCode(countryCode: countryCode),
      );
    }

    var region = (currencyRegion ?? '').toLowerCase();
    if (region.isEmpty && languageCode != null) {
      region = _defaultVetCurrencyRegionForLanguage(
        languageCode,
        countryCode: countryCode,
      );
    }
    if (region == 'bih' || region == 'rs') return vetScanCapBalkan;
    if (region == 'eu' || region == 'se') return vetScanCapEu;

    final code = _resolvePricingCountryCode(
      countryCode: countryCode,
      currencyRegion: currencyRegion,
      languageCode: languageCode,
    );
    final zone = zoneForCountry(code, languageCode: languageCode);
    switch (zone) {
      case BusinessPricingZone.bih:
      case BusinessPricingZone.serbia:
        return vetScanCapBalkan;
      case BusinessPricingZone.eu:
      case BusinessPricingZone.developed:
      case BusinessPricingZone.emerging:
        return vetScanCapEu;
    }
  }

  /// Mjesečni limit AI skenova za kupca / farmer pretplatu — proporcionalno cijeni paketa.
  /// EU / SE / UA / RU / CH @ 9,99 € referenci: puni [SubscriptionLimits] cap.
  /// BiH @ 9,99 KM: pola capa. Srbija: proporcionalno RSD cijeni (~599 RSD).
  static int resolveSubscriptionMonthlyScanCap({
    required SubscriptionTier tier,
    required String? currencyRegion,
    required String languageCode,
    String? countryCode,
  }) {
    final euCap = SubscriptionLimits.monthlyScansForTier(tier);

    final billingCountry = (countryCode ??
            resolveBillingCountryForPricing() ??
            '')
        .toUpperCase();
    if (billingCountry.isNotEmpty) {
      if (billingCountry == 'TR') {
        return turkeyAdjustedScanCap(euCap);
      }
      if (billingCountry == 'IN' || billingCountry == 'ID') {
        return emergingAsiaAdjustedScanCap(euCap);
      }
      if (billingCountry == 'KE') {
        return kenyaAdjustedScanCap(euCap);
      }
      if (ArabicMarketPricing.arabCountries.contains(billingCountry)) {
        return ArabicMarketPricing.adjustedScanCap(
          euCap,
          billingCountry,
        );
      }

      final zone = zoneForCountry(billingCountry, languageCode: languageCode);
      switch (zone) {
        case BusinessPricingZone.bih:
          return _halfScanCap(euCap);
        case BusinessPricingZone.serbia:
          return _proportionalScanCapFromPrice(
            euCap,
            _serbiaPremiumPriceEur(),
          );
        case BusinessPricingZone.eu:
        case BusinessPricingZone.developed:
          return euCap;
        case BusinessPricingZone.emerging:
          return _proportionalScanCapFromPrice(
            euCap,
            _emergingTierEur(vetEuMonthlyEur, billingCountry),
          );
      }
    }

    if (isEmergingAsiaPricingContext(
      languageCode: languageCode,
      countryCode: countryCode,
    )) {
      return emergingAsiaAdjustedScanCap(euCap);
    }
    if (isKenyaPricingContext(
      languageCode: languageCode,
      countryCode: countryCode,
    )) {
      return kenyaAdjustedScanCap(euCap);
    }
    if (isTurkeyPricingContext(
      languageCode: languageCode,
      countryCode: countryCode,
    )) {
      return turkeyAdjustedScanCap(euCap);
    }
    if (ArabicMarketPricing.isArabicPricingContext(
      languageCode: languageCode,
      countryCode: countryCode,
    )) {
      return ArabicMarketPricing.adjustedScanCap(
        euCap,
        _resolveArabCountryCode(countryCode: countryCode),
      );
    }

    var region = (currencyRegion ?? '').toLowerCase();
    if (region.isEmpty) {
      region = _defaultVetCurrencyRegionForLanguage(
        languageCode,
        countryCode: countryCode,
      );
    }

    if (region == 'bih') {
      return _halfScanCap(euCap);
    }
    if (region == 'rs') {
      return _proportionalScanCapFromPrice(
        euCap,
        _serbiaPremiumPriceEur(),
      );
    }
    if (region == 'eu' ||
        region == 'se' ||
        _isSekLockedLanguageCode(languageCode) ||
        _isUahLockedLanguageCode(languageCode) ||
        _isRubLockedLanguageCode(languageCode)) {
      return euCap;
    }

    final code = _resolvePricingCountryCode(
      countryCode: countryCode,
      currencyRegion: currencyRegion,
      languageCode: languageCode,
    );
    final zone = zoneForCountry(code, languageCode: languageCode);
    switch (zone) {
      case BusinessPricingZone.bih:
        return _halfScanCap(euCap);
      case BusinessPricingZone.serbia:
        return _proportionalScanCapFromPrice(
          euCap,
          _serbiaPremiumPriceEur(),
        );
      case BusinessPricingZone.eu:
      case BusinessPricingZone.developed:
        return euCap;
      case BusinessPricingZone.emerging:
        return _proportionalScanCapFromPrice(
          euCap,
          _emergingTierEur(vetEuMonthlyEur, code),
        );
    }
  }

  /// Dokup = pola mjesečne alokacije (min. 1 sken).
  static int topUpPackSizeFromMonthlyLimit(int monthlyLimit) {
    if (monthlyLimit <= 0) return 0;
    final half = (monthlyLimit / 2).round();
    return half < 1 ? 1 : half;
  }

  static int _halfScanCap(int euCap) {
    final cap = (euCap / 2).round();
    return cap < 1 ? 1 : cap;
  }

  static int _proportionalScanCapFromPrice(int euCap, double priceEur) {
    final cap = (euCap * priceEur / vetEuMonthlyEur).round();
    return cap < 1 ? 1 : cap;
  }

  static double _serbiaPremiumPriceEur() {
    return vetSerbiaMonthlyRsd / CurrencyService.eurToRsd;
  }

  static String vetScannerBenefitLine({
    required String languageCode,
    required String? currencyRegion,
    String? countryCode,
  }) {
    final count = resolveVetMonthlyScanCap(
      currencyRegion: currencyRegion,
      languageCode: languageCode,
      countryCode: countryCode,
    );
    final lang = _normalizeLanguage(languageCode);
    switch (lang) {
      case 'de':
        return 'KI-Pflanzenscanner — $count Scans pro Monat';
      case 'en':
        return 'AI Plant Scanner — $count scans per month';
      case 'es':
        return 'Escáner IA de plantas — $count escaneos al mes';
      case 'fr':
        return 'Scanner IA des plantes — $count scans par mois';
      case 'it':
        return 'Scanner IA delle piante — $count scansioni al mese';
      case 'cs':
        return 'AI skener rostlin — $count skenů měsíčně';
      case 'sr':
        return 'AI Skener biljaka — $count skeniranja mesečno';
      case 'sv':
        return 'AI-växtskanner — $count skanningar per månad';
      case 'pl':
        return 'Skaner AI roślin — $count skanów miesięcznie';
      case 'zh':
        return 'AI 植物扫描 — 每月 $count 次';
      case 'uk':
        return 'ШІ-сканер рослин — $count сканувань на місяць';
      case 'ru':
        return 'ИИ-сканер растений — $count сканирований в месяц';
      case 'hi':
        return 'AI पौधा स्कैनर — प्रति माह $count स्कैन';
      case 'id':
        return 'Pemindai AI Tanaman — $count pemindaian per bulan';
      case 'sw':
        return 'AI Kichanganuzi cha Mimea — skani $count kwa mwezi';
      case 'ar':
        return 'ماسح AI للنباتات — $count عملية مسح/الشهر';
      case 'tr':
        return 'AI Bitki Tarayıcı — ayda $count tarama';
      default:
        return 'AI Skener biljaka — $count skeniranja mjesečno';
    }
  }

  /// Mjesečna cijena Premium Veterinar — GPS/IP država, ne jezik sučelja.
  static String vetPriceLine({
    required String languageCode,
    required String? currencyRegion,
    String? countryCode,
    String? paymentCountryCode,
  }) {
    final lang = _normalizeLanguage(languageCode);
    final billingCountry = (countryCode ??
            resolveBillingCountryForPricing(
              paymentCountryCode: paymentCountryCode,
            ) ??
            '')
        .toUpperCase();
    final region = vetCurrencyRegion(
      languageCode: languageCode,
      currencyRegion: currencyRegion,
      countryCode: billingCountry.isNotEmpty ? billingCountry : null,
    );

    if (billingCountry.isNotEmpty) {
      if (billingCountry == 'TR') {
        return _formatMonthlyPriceLine(
          amount: _convertFromEur(
            turkeyAdjustedEur(vetEuMonthlyEur),
            CurrencyService.try_,
          ),
          currencyCode: CurrencyService.try_,
          languageCode: languageCode,
        );
      }
      if (billingCountry == 'IN') {
        return _formatMonthlyPriceLine(
          amount: _convertFromEur(
            emergingAsiaAdjustedEur(vetEuMonthlyEur),
            CurrencyService.inr,
          ),
          currencyCode: CurrencyService.inr,
          languageCode: languageCode,
        );
      }
      if (billingCountry == 'ID') {
        return _formatMonthlyPriceLine(
          amount: _convertFromEur(
            emergingAsiaAdjustedEur(vetEuMonthlyEur),
            CurrencyService.idr,
          ),
          currencyCode: CurrencyService.idr,
          languageCode: languageCode,
        );
      }
      if (billingCountry == 'KE') {
        return _formatMonthlyPriceLine(
          amount: _convertFromEur(
            kenyaAdjustedEur(vetEuMonthlyEur),
            CurrencyService.kes,
          ),
          currencyCode: CurrencyService.kes,
          languageCode: languageCode,
        );
      }
      if (ArabicMarketPricing.arabCountries.contains(billingCountry)) {
        final currencyCode =
            ArabicMarketPricing.currencyCodeForCountry(billingCountry);
        return _formatMonthlyPriceLine(
          amount: _convertFromEur(
            ArabicMarketPricing.adjustedEur(vetEuMonthlyEur, billingCountry),
            currencyCode,
          ),
          currencyCode: currencyCode,
          languageCode: languageCode,
        );
      }
      if (billingCountry == 'CN') {
        return _formatMonthlyPriceLine(
          amount: _convertFromEur(vetEuMonthlyEur, CurrencyService.cny),
          currencyCode: CurrencyService.cny,
          languageCode: languageCode,
        );
      }
      if (billingCountry == 'UA') {
        return _formatMonthlyPriceLine(
          amount: _convertFromEur(vetEuMonthlyEur, CurrencyService.uah),
          currencyCode: CurrencyService.uah,
          languageCode: languageCode,
        );
      }
      if (billingCountry == 'RU') {
        return _formatMonthlyPriceLine(
          amount: _convertFromEur(vetEuMonthlyEur, CurrencyService.rub),
          currencyCode: CurrencyService.rub,
          languageCode: languageCode,
        );
      }
      if (billingCountry == 'BA') {
        return '$vetBihFlatPriceDisplay${_monthlyPeriodSuffix(lang)}';
      }
      if (billingCountry == 'RS') {
        return _vetSerbiaFlatPriceLine(languageCode);
      }
      if (billingCountry == 'CH') {
        return _formatMonthlyPriceLine(
          amount: SwissMarketPricing.chfAmount(vetEuMonthlyEur),
          currencyCode: CurrencyService.chf,
          languageCode: languageCode,
        );
      }
      if (billingCountry == 'SE') {
        final regional = subscriptionPriceLineForProduct(
          productId: RevenueCatConfig.licenseVetMonthly,
          languageCode: languageCode,
          countryCode: 'SE',
          currencyRegion: region,
        );
        if (regional != null) return regional;
      }

      final zone = zoneForCountry(billingCountry, languageCode: languageCode);
      switch (zone) {
        case BusinessPricingZone.bih:
          return '$vetBihFlatPriceDisplay${_monthlyPeriodSuffix(lang)}';
        case BusinessPricingZone.serbia:
          return _vetSerbiaFlatPriceLine(languageCode);
        case BusinessPricingZone.eu:
        case BusinessPricingZone.developed:
          return _formatMonthlyPriceLine(
            amount: vetEuMonthlyEur,
            currencyCode: CurrencyService.eur,
            languageCode: languageCode,
          );
        case BusinessPricingZone.emerging:
          final eur = _emergingTierEur(vetEuMonthlyEur, billingCountry);
          final code =
              CurrencyService().currencyCodeFromCountry(billingCountry);
          return _formatMonthlyPriceLine(
            amount: _convertFromEur(eur, code),
            currencyCode: code,
            languageCode: languageCode,
          );
      }
    }

    // Ručni izbor regije (dijaspora) kad nema GPS/IP.
    if (lang == 'sr') {
      if (region == 'bih') {
        return '$vetBihFlatPriceDisplay${_monthlyPeriodSuffix(lang)}';
      }
      return _vetSerbiaFlatPriceLine(languageCode);
    }

    if (region == 'bih') {
      return '$vetBihFlatPriceDisplay${_monthlyPeriodSuffix(lang)}';
    }
    if (region == 'rs') {
      return _vetSerbiaFlatPriceLine(languageCode);
    }
    if (region == 'eu') {
      return _formatMonthlyPriceLine(
        amount: vetEuMonthlyEur,
        currencyCode: CurrencyService.eur,
        languageCode: languageCode,
      );
    }

    return _formatMonthlyPriceLine(
      amount: vetEuMonthlyEur,
      currencyCode: CurrencyService.eur,
      languageCode: languageCode,
    );
  }

  /// Gumb pretplate za veterinara — valuta iz profila (KM samo za regiju BiH).
  static String vetCurrencyRegion({
    required String languageCode,
    required String? currencyRegion,
    String? countryCode,
  }) {
    final billingCountry = (countryCode ??
            resolveBillingCountryForPricing() ??
            '')
        .toUpperCase();
    if (billingCountry.isNotEmpty) {
      if (billingCountry == 'BA') return 'bih';
      if (billingCountry == 'RS') return 'rs';
      if (billingCountry == 'SE') return 'se';
      if (isEuCountryCode(billingCountry) ||
          isDevelopedCountryCode(billingCountry)) {
        return 'eu';
      }
      if (isEmergingMarketCountry(billingCountry)) return 'emerging';
      return 'eu';
    }
    if (_normalizeLanguage(languageCode) == 'sr') {
      final stored = (currencyRegion ?? '').toLowerCase();
      if (stored == 'bih' || stored == 'rs') return stored;
      return 'rs';
    }
    final region = (currencyRegion ?? '').toLowerCase();
    if (region.isNotEmpty) return region;
    return _defaultVetCurrencyRegionForLanguage(
      languageCode,
      countryCode: countryCode,
    );
  }

  static String _defaultVetCurrencyRegionForLanguage(
    String languageCode, {
    String? countryCode,
  }) {
    final lang = _normalizeLanguage(languageCode);
    if (lang == 'bs') return 'bih';
    if (lang == 'sr') {
      final code = (countryCode ?? cachedDeviceCountryCode ?? '').toUpperCase();
      return code == 'BA' ? 'bih' : 'rs';
    }
    if (lang == 'hr') {
      final code = (countryCode ?? cachedDeviceCountryCode ?? '').toUpperCase();
      if (code == 'BA') return 'bih';
      return 'eu';
    }
    if (lang == 'sv') return 'se';
    if (lang == 'zh') return 'cn';
    return 'eu';
  }

  static String vetSubscribeButtonLabel({
    required String languageCode,
    required String? currencyRegion,
    String? countryCode,
    String? paymentCountryCode,
  }) {
    final lang = _normalizeLanguage(languageCode);
    final priceLine = vetPriceLine(
      languageCode: languageCode,
      currencyRegion: currencyRegion,
      countryCode: countryCode,
      paymentCountryCode: paymentCountryCode,
    );

    switch (lang) {
      case 'de':
        return 'Abonnieren — $priceLine';
      case 'en':
        return 'Subscribe — $priceLine';
      case 'es':
        return 'Suscribirme — $priceLine';
      case 'fr':
        return 'S\'abonner — $priceLine';
      case 'it':
        return 'Abbonati — $priceLine';
      case 'cs':
        return 'Předplatit — $priceLine';
      case 'pl':
        return 'Subskrybuj — $priceLine';
      case 'sv':
        return 'Prenumerera — $priceLine';
      case 'zh':
        return '订阅 — $priceLine';
      case 'uk':
        return 'Підписатися — $priceLine';
      case 'ru':
        return 'Подписаться — $priceLine';
      case 'hi':
        return 'सदस्यता लें — $priceLine';
      case 'id':
        return 'Berlangganan — $priceLine';
      case 'sw':
        return 'Jisajili — $priceLine';
      case 'ar':
        return 'اشترك — $priceLine';
      case 'tr':
        return 'Abone ol — $priceLine';
      default:
        return 'Pretplati me — $priceLine';
    }
  }

  /// Mjesečna cijena Hobi Farmer Premium — GPS/IP država, ne jezik sučelja.
  static String hobbyPriceLine({
    required String languageCode,
    String? countryCode,
    String? currencyRegion,
    String? paymentCountryCode,
  }) {
    return subscriptionPriceLineForProduct(
          productId: RevenueCatConfig.premiumHobbyMonthly,
          languageCode: languageCode,
          countryCode: countryCode,
          currencyRegion: currencyRegion,
          paymentCountryCode: paymentCountryCode,
        ) ??
        _formatMonthlyPriceLine(
          amount: SubscriptionLimits.monthlyPriceEur(
            SubscriptionTier.hobbyFarmerPremium,
          ),
          currencyCode: CurrencyService.eur,
          languageCode: languageCode,
        );
  }

  static String hobbyScannerBenefitLine({
    required String languageCode,
    String? countryCode,
    String? currencyRegion,
  }) {
    final count = resolveSubscriptionMonthlyScanCap(
      tier: SubscriptionTier.hobbyFarmerPremium,
      currencyRegion: currencyRegion,
      languageCode: languageCode,
      countryCode: countryCode,
    );
    final lang = _normalizeLanguage(languageCode);
    switch (lang) {
      case 'de':
        return 'KI-Pflanzenscanner — $count Scans pro Monat';
      case 'en':
        return 'AI Plant Scanner — $count scans per month';
      case 'es':
        return 'Escáner IA de plantas — $count escaneos al mes';
      case 'fr':
        return 'Scanner IA des plantes — $count scans par mois';
      case 'it':
        return 'Scanner IA delle piante — $count scansioni al mese';
      case 'cs':
        return 'AI skener rostlin — $count skenů měsíčně';
      case 'sr':
        return 'AI Skener biljaka — $count skeniranja mesečno';
      case 'sv':
        return 'AI-växtskanner — $count skanningar per månad';
      case 'pl':
        return 'Skaner AI roślin — $count skanów miesięcznie';
      case 'zh':
        return 'AI 植物扫描 — 每月 $count 次';
      case 'uk':
        return 'ШІ-сканер рослин — $count сканувань на місяць';
      case 'ru':
        return 'ИИ-сканер растений — $count сканирований в месяц';
      case 'hi':
        return 'AI पौधा स्कैनर — प्रति माह $count स्कैन';
      case 'id':
        return 'Pemindai AI Tanaman — $count pemindaian per bulan';
      case 'sw':
        return 'Kichanganuzi cha AI cha Mimea — skani $count kwa mwezi';
      case 'ar':
        return 'ماسح النباتات بالذكاء الاصطناعي — $count مسحًا شهريًا';
      case 'tr':
        return 'AI Bitki Tarayıcı — ayda $count tarama';
      default:
        return 'AI Skener biljaka — $count skeniranja mjesečno';
    }
  }

  static String hobbySubscribeButtonLabel({
    required String languageCode,
    String? countryCode,
    String? currencyRegion,
    String? paymentCountryCode,
  }) {
    final lang = _normalizeLanguage(languageCode);
    final priceLine = hobbyPriceLine(
      languageCode: languageCode,
      countryCode: countryCode,
      currencyRegion: currencyRegion,
      paymentCountryCode: paymentCountryCode,
    );

    switch (lang) {
      case 'de':
        return 'Premium starten — $priceLine';
      case 'en':
        return 'Start Premium — $priceLine';
      case 'es':
        return 'Activar Premium — $priceLine';
      case 'fr':
        return 'Activer Premium — $priceLine';
      case 'it':
        return 'Attiva Premium — $priceLine';
      case 'cs':
        return 'Spustit Premium — $priceLine';
      case 'pl':
        return 'Uruchom Premium — $priceLine';
      case 'sv':
        return 'Starta Premium — $priceLine';
      case 'zh':
        return '开通 Premium — $priceLine';
      case 'uk':
        return 'Активувати Premium — $priceLine';
      case 'ru':
        return 'Активировать Premium — $priceLine';
      case 'hi':
        return 'Premium शुरू करें — $priceLine';
      case 'id':
        return 'Mulai Premium — $priceLine';
      case 'sw':
        return 'Anza Premium — $priceLine';
      case 'ar':
        return 'ابدأ Premium — $priceLine';
      case 'tr':
        return 'Premium\'u başlat — $priceLine';
      default:
        return 'Pokreni Premium — $priceLine';
    }
  }

  /// Mjesečna cijena Pro Farmer Premium — GPS/IP država, ne jezik sučelja.
  static String proPriceLine({
    required String languageCode,
    String? countryCode,
    String? currencyRegion,
    String? paymentCountryCode,
  }) {
    return subscriptionPriceLineForProduct(
          productId: RevenueCatConfig.premiumProMonthly,
          languageCode: languageCode,
          countryCode: countryCode,
          currencyRegion: currencyRegion,
          paymentCountryCode: paymentCountryCode,
        ) ??
        _formatMonthlyPriceLine(
          amount: SubscriptionLimits.monthlyPriceEur(
            SubscriptionTier.professionalFarmerPremium,
          ),
          currencyCode: CurrencyService.eur,
          languageCode: languageCode,
        );
  }

  static String proScannerBenefitLine({
    required String languageCode,
    String? countryCode,
    String? currencyRegion,
  }) {
    final count = resolveSubscriptionMonthlyScanCap(
      tier: SubscriptionTier.professionalFarmerPremium,
      currencyRegion: currencyRegion,
      languageCode: languageCode,
      countryCode: countryCode,
    );
    final lang = _normalizeLanguage(languageCode);
    switch (lang) {
      case 'de':
        return 'KI-Pflanzenscanner — $count Scans pro Monat';
      case 'en':
        return 'AI Plant Scanner — $count scans per month';
      case 'es':
        return 'Escáner IA de plantas — $count escaneos al mes';
      case 'fr':
        return 'Scanner IA des plantes — $count scans par mois';
      case 'it':
        return 'Scanner IA delle piante — $count scansioni al mese';
      case 'cs':
        return 'AI skener rostlin — $count skenů měsíčně';
      case 'sr':
        return 'AI Skener biljaka — $count skeniranja mesečno';
      case 'sv':
        return 'AI-växtskanner — $count skanningar per månad';
      case 'pl':
        return 'Skaner AI roślin — $count skanów miesięcznie';
      case 'zh':
        return 'AI 植物扫描 — 每月 $count 次';
      case 'uk':
        return 'ШІ-сканер рослин — $count сканувань на місяць';
      case 'ru':
        return 'ИИ-сканер растений — $count сканирований в месяц';
      case 'hi':
        return 'AI पौधा स्कैनर — प्रति माह $count स्कैन';
      case 'id':
        return 'Pemindai AI Tanaman — $count pemindaian per bulan';
      case 'sw':
        return 'Kichanganuzi cha AI cha Mimea — skani $count kwa mwezi';
      case 'ar':
        return 'ماسح النباتات بالذكاء الاصطناعي — $count مسحًا شهريًا';
      case 'tr':
        return 'AI Bitki Tarayıcı — ayda $count tarama';
      default:
        return 'AI Skener biljaka — $count skeniranja mjesečno';
    }
  }

  static String proSubscribeButtonLabel({
    required String languageCode,
    String? countryCode,
    String? currencyRegion,
    String? paymentCountryCode,
  }) {
    final lang = _normalizeLanguage(languageCode);
    final priceLine = proPriceLine(
      languageCode: languageCode,
      countryCode: countryCode,
      currencyRegion: currencyRegion,
      paymentCountryCode: paymentCountryCode,
    );

    switch (lang) {
      case 'de':
        return 'Premium Pro starten — $priceLine';
      case 'en':
        return 'Start Premium Pro — $priceLine';
      case 'es':
        return 'Activar Premium Pro — $priceLine';
      case 'fr':
        return 'Activer Premium Pro — $priceLine';
      case 'it':
        return 'Attiva Premium Pro — $priceLine';
      case 'cs':
        return 'Spustit Premium Pro — $priceLine';
      case 'pl':
        return 'Uruchom Premium Pro — $priceLine';
      case 'sv':
        return 'Starta Premium Pro — $priceLine';
      case 'zh':
        return '开通 Premium Pro — $priceLine';
      case 'uk':
        return 'Активувати Premium Pro — $priceLine';
      case 'ru':
        return 'Активировать Premium Pro — $priceLine';
      case 'hi':
        return 'Premium Pro शुरू करें — $priceLine';
      case 'id':
        return 'Mulai Premium Pro — $priceLine';
      case 'sw':
        return 'Anza Premium Pro — $priceLine';
      case 'ar':
        return 'ابدأ Premium Pro — $priceLine';
      case 'tr':
        return 'Premium Pro\'yu başlat — $priceLine';
      default:
        return 'Pokreni Premium Pro — $priceLine';
    }
  }

  /// Regionalna cijena poslovne pretplate — regija uređaja nadjačava jezik.
  static CompanySubscriptionQuote quoteForCountry(
    String countryCode, {
    required String languageCode,
    DeviceRegionSource source = DeviceRegionSource.fallback,
  }) {
    final zone = zoneForCountry(countryCode, languageCode: languageCode);
    late double amount;
    late String currencyCode;
    late double amountEur;
    late String priceLine;

    switch (zone) {
      case BusinessPricingZone.eu:
        amount = companyEuMonthlyEur;
        currencyCode = CurrencyService.eur;
        amountEur = companyEuMonthlyEur;
        priceLine = _formatMonthlyPriceLine(
          amount: amount,
          currencyCode: currencyCode,
          languageCode: languageCode,
        );
        break;
      case BusinessPricingZone.bih:
        amount = companyBihMonthlyKm;
        currencyCode = CurrencyService.bam;
        amountEur = companyBihMonthlyKm / CurrencyService.eurToBam;
        priceLine = _bihFlatPriceLine(languageCode);
        break;
      case BusinessPricingZone.serbia:
        amount = companySerbiaMonthlyRsd;
        currencyCode = CurrencyService.rsd;
        amountEur = companySerbiaMonthlyRsd / CurrencyService.eurToRsd;
        priceLine = _serbiaFlatPriceLine(languageCode);
        break;
      case BusinessPricingZone.developed:
        amount = companyEuMonthlyEur;
        currencyCode = _currencyCodeForDevelopedCountry(countryCode);
        amountEur = companyEuMonthlyEur;
        if (currencyCode != CurrencyService.eur) {
          amount = _convertFromEur(amountEur, currencyCode);
        }
        priceLine = _formatMonthlyPriceLine(
          amount: amount,
          currencyCode: currencyCode,
          languageCode: languageCode,
        );
        break;
      case BusinessPricingZone.emerging:
        final pppFactor = _pppFactorForCountry(countryCode);
        amountEur = companyEuMonthlyEur * pppFactor;
        if (amountEur < aiNoLossFloorEur) {
          amountEur = aiNoLossFloorEur;
        }
        currencyCode = CurrencyService.eur;
        amount = amountEur;
        priceLine = _formatMonthlyPriceLine(
          amount: amount,
          currencyCode: currencyCode,
          languageCode: languageCode,
        );
        break;
    }

    if (_isSekLockedLanguageCode(languageCode)) {
      amountEur = companyEuMonthlyEur;
      currencyCode = CurrencyService.sek;
      amount = _convertFromEur(amountEur, CurrencyService.sek);
      priceLine = _formatMonthlyPriceLine(
        amount: amount,
        currencyCode: currencyCode,
        languageCode: languageCode,
      );
    }

    if (_isUahLockedLanguageCode(languageCode)) {
      amountEur = companyEuMonthlyEur;
      currencyCode = CurrencyService.uah;
      amount = _convertFromEur(amountEur, CurrencyService.uah);
      priceLine = _formatMonthlyPriceLine(
        amount: amount,
        currencyCode: currencyCode,
        languageCode: languageCode,
      );
    }

    if (_isRubLockedLanguageCode(languageCode)) {
      amountEur = companyEuMonthlyEur;
      currencyCode = CurrencyService.rub;
      amount = _convertFromEur(amountEur, CurrencyService.rub);
      priceLine = _formatMonthlyPriceLine(
        amount: amount,
        currencyCode: currencyCode,
        languageCode: languageCode,
      );
    }

    if (_isInrLockedLanguageCode(languageCode)) {
      amountEur = emergingAsiaAdjustedEur(companyEuMonthlyEur);
      currencyCode = CurrencyService.inr;
      amount = _convertFromEur(amountEur, CurrencyService.inr);
      priceLine = _formatMonthlyPriceLine(
        amount: amount,
        currencyCode: currencyCode,
        languageCode: languageCode,
      );
    }

    if (_isIdrLockedLanguageCode(languageCode)) {
      amountEur = emergingAsiaAdjustedEur(companyEuMonthlyEur);
      currencyCode = CurrencyService.idr;
      amount = _convertFromEur(amountEur, CurrencyService.idr);
      priceLine = _formatMonthlyPriceLine(
        amount: amount,
        currencyCode: currencyCode,
        languageCode: languageCode,
      );
    }

    if (_isKesLockedLanguageCode(languageCode)) {
      amountEur = kenyaAdjustedEur(companyEuMonthlyEur);
      currencyCode = CurrencyService.kes;
      amount = _convertFromEur(amountEur, CurrencyService.kes);
      priceLine = _formatMonthlyPriceLine(
        amount: amount,
        currencyCode: currencyCode,
        languageCode: languageCode,
      );
    }

    if (_isTryLockedLanguageCode(languageCode)) {
      amountEur = turkeyAdjustedEur(companyEuMonthlyEur);
      currencyCode = CurrencyService.try_;
      amount = _convertFromEur(amountEur, CurrencyService.try_);
      priceLine = _formatMonthlyPriceLine(
        amount: amount,
        currencyCode: currencyCode,
        languageCode: languageCode,
      );
    }

    if (_isArabicLockedLanguageCode(languageCode)) {
      final arabCountry = _resolveArabCountryCode(countryCode: countryCode);
      amountEur = ArabicMarketPricing.adjustedEur(
        companyEuMonthlyEur,
        arabCountry,
      );
      currencyCode = ArabicMarketPricing.currencyCodeForCountry(arabCountry);
      amount = _convertFromEur(amountEur, currencyCode);
      priceLine = _formatMonthlyPriceLine(
        amount: amount,
        currencyCode: currencyCode,
        languageCode: languageCode,
      );
    }

    if (isSwissDeFrPricingContext(
      languageCode: languageCode,
      countryCode: countryCode,
    )) {
      amountEur = SwissMarketPricing.adjustedEur(companyEuMonthlyEur);
      currencyCode = CurrencyService.chf;
      amount = SwissMarketPricing.chfAmount(companyEuMonthlyEur);
      priceLine = _formatMonthlyPriceLine(
        amount: amount,
        currencyCode: currencyCode,
        languageCode: languageCode,
      );
    }

    final activateButtonLabel = _formatActivateButtonLabel(
      languageCode: languageCode,
      priceLine: priceLine,
    );

    return CompanySubscriptionQuote(
      countryCode: countryCode.toUpperCase(),
      zone: zone,
      amount: amount,
      currencyCode: currencyCode,
      amountEurEquivalent: amountEur,
      source: source,
      priceLine: priceLine,
      activateButtonLabel: activateButtonLabel,
    );
  }

  /// Dinamička ponuda — GPS + valutna regija iz profila (kao kod veterinara).
  Future<CompanySubscriptionQuote> resolveCompanySubscriptionQuote({
    required String languageCode,
    String? currencyRegion,
  }) async {
    final device = await resolveDeviceCountryForPricing();
    final countryCode = _resolveCompanyCountryCode(
      countryCode: device?.countryCode ??
          cachedDeviceCountryCode ??
          (await resolveDeviceCountry()).countryCode,
      currencyRegion: currencyRegion,
      languageCode: languageCode,
    );
    return quoteForCountry(
      countryCode,
      languageCode: languageCode,
      source: device?.source ?? _cachedSource ?? DeviceRegionSource.fallback,
    );
  }

  static String formatCompanyPriceLine(
    BuildContext context,
    CompanySubscriptionQuote quote,
  ) {
    return quote.priceLine;
  }

  static String formatCompanyActivateButtonLabel(
    BuildContext context,
    CompanySubscriptionQuote quote,
  ) {
    return quote.activateButtonLabel;
  }

  /// Cijena dokupa skenova — pola mjesečnog paketa, 0,10 € API + 0,05 € marža po skenu.
  static double scanTopUpPackPriceEur(int packSize) =>
      packSize * scanTopUpUnitPriceEur;

  static String _formatOneTimePriceLine({
    required double amount,
    required String currencyCode,
  }) {
    return _formatAmount(amount, currencyCode);
  }

  static String scanTopUpPackPriceLine({
    required int packSize,
    required String languageCode,
    String? currencyRegion,
    String? countryCode,
  }) {
    final eur = scanTopUpPackPriceEur(packSize);
    final region = (currencyRegion ?? '').toLowerCase();
    final billingCode = (countryCode ??
            resolveBillingCountryForPricing() ??
            '')
        .toUpperCase();

    // Valuta prati lokaciju / regiju naplate — ne jezik sučelja.
    if (region == 'bih' || billingCode == 'BA') {
      return _formatOneTimePriceLine(
        amount: eur * CurrencyService.eurToBam,
        currencyCode: CurrencyService.bam,
      );
    }
    if (region == 'rs' || billingCode == 'RS') {
      return _formatOneTimePriceLine(
        amount: eur * CurrencyService.eurToRsd,
        currencyCode: CurrencyService.rsd,
      );
    }
    if (region == 'se' || billingCode == 'SE') {
      return _formatOneTimePriceLine(
        amount: eur * CurrencyService.eurToSek,
        currencyCode: CurrencyService.sek,
      );
    }
    if (billingCode == 'CH') {
      return _formatOneTimePriceLine(
        amount: SwissMarketPricing.chfAmount(eur),
        currencyCode: CurrencyService.chf,
      );
    }
    if (billingCode == 'UA') {
      return _formatOneTimePriceLine(
        amount: _convertFromEur(eur, CurrencyService.uah),
        currencyCode: CurrencyService.uah,
      );
    }
    if (billingCode == 'RU') {
      return _formatOneTimePriceLine(
        amount: _convertFromEur(eur, CurrencyService.rub),
        currencyCode: CurrencyService.rub,
      );
    }

    return _formatOneTimePriceLine(
      amount: eur,
      currencyCode: CurrencyService.eur,
    );
  }

  static String scanTopUpButtonLabel({
    required int packSize,
    required String languageCode,
    String? currencyRegion,
    String? countryCode,
  }) {
    final price = scanTopUpPackPriceLine(
      packSize: packSize,
      languageCode: languageCode,
      currencyRegion: currencyRegion,
      countryCode: countryCode,
    );
    final lang = _normalizeLanguage(languageCode);
    switch (lang) {
      case 'de':
        return '+$packSize Scans kaufen — $price';
      case 'en':
        return 'Buy +$packSize scans — $price';
      case 'sv':
        return 'Köp +$packSize skanningar — $price';
      default:
        return 'Dokupi +$packSize skenova — $price';
    }
  }

  static String _bihFlatPriceLine(String languageCode) {
    return '$bihFlatPriceDisplay${_monthlyPeriodSuffix(_normalizeLanguage(languageCode))}';
  }

  static String _serbiaFlatPriceLine(String languageCode) {
    return '$serbiaFlatPriceDisplay${_monthlyPeriodSuffix(_normalizeLanguage(languageCode))}';
  }

  static String _resolvePricingCountryCode({
    String? countryCode,
    String? currencyRegion,
    String? languageCode,
  }) {
    if (currencyRegion == 'bih') return 'BA';
    if (currencyRegion == 'rs') return 'RS';
    if (currencyRegion == 'se') return 'SE';
    if (currencyRegion == 'eu') {
      final gps = (countryCode ?? cachedDeviceCountryCode ?? '').toUpperCase();
      if (gps == 'CH') return 'CH';
      if (gps.isNotEmpty && _euCountryCodes.contains(gps)) return gps;
      final lang = _normalizeLanguage(languageCode ?? '');
      if (lang == 'hr') return 'HR';
      if (lang == 'de') return 'DE';
      if (lang == 'pl') return 'PL';
      if (lang == 'es') return 'ES';
      if (lang == 'fr') return 'FR';
      if (lang == 'cs') return 'CZ';
      if (lang == 'it') return 'IT';
      return 'DE';
    }
    return (countryCode ?? cachedDeviceCountryCode ?? 'DE').toUpperCase();
  }

  static double _balkanMonthlyEurForProduct(String productId) {
    switch (productId) {
      case RevenueCatConfig.premiumBuyerMonthly:
        return 1.99 / CurrencyService.eurToBam;
      case RevenueCatConfig.premiumHobbyMonthly:
        return 3.99 / CurrencyService.eurToBam;
      case RevenueCatConfig.premiumProMonthly:
        return 9.99 / CurrencyService.eurToBam;
      case RevenueCatConfig.licenseVetMonthly:
        return vetBihMonthlyKm / CurrencyService.eurToBam;
      case RevenueCatConfig.licensePharmacyMonthly:
        return companyBihMonthlyKm / CurrencyService.eurToBam;
      default:
        return companyBihMonthlyKm / CurrencyService.eurToBam;
    }
  }

  static String? _balkanFlatPriceLineForProduct({
    required String productId,
    required BusinessPricingZone zone,
    required String languageCode,
  }) {
    if (zone != BusinessPricingZone.bih &&
        zone != BusinessPricingZone.serbia) {
      return null;
    }
    final suffix = _monthlyPeriodSuffix(_normalizeLanguage(languageCode));
    final isBih = zone == BusinessPricingZone.bih;
    switch (productId) {
      case RevenueCatConfig.premiumBuyerMonthly:
        return isBih
            ? '$balkanBuyerKmDisplay$suffix'
            : '$balkanBuyerRsdDisplay$suffix';
      case RevenueCatConfig.premiumHobbyMonthly:
        return isBih
            ? '$balkanHobbyKmDisplay$suffix'
            : '$balkanHobbyRsdDisplay$suffix';
      case RevenueCatConfig.premiumProMonthly:
      case RevenueCatConfig.licenseVetMonthly:
        return isBih
            ? '$balkanPremiumKmDisplay$suffix'
            : '$balkanPremiumRsdDisplay$suffix';
      case RevenueCatConfig.licensePharmacyMonthly:
        return isBih
            ? _bihFlatPriceLine(languageCode)
            : _serbiaFlatPriceLine(languageCode);
      default:
        return null;
    }
  }

  static String _vetSerbiaFlatPriceLine(String languageCode) {
    return '$vetSerbiaFlatPriceDisplay${_monthlyPeriodSuffix(_normalizeLanguage(languageCode))}';
  }

  static String _formatMonthlyPriceLine({
    required double amount,
    required String currencyCode,
    required String languageCode,
  }) {
    final lang = _normalizeLanguage(languageCode);
    final formatted = _formatAmount(amount, currencyCode);
    final period = _monthlyPeriodSuffix(lang);
    return '$formatted$period';
  }

  static String _formatActivateButtonLabel({
    required String languageCode,
    required String priceLine,
  }) {
    final lang = _normalizeLanguage(languageCode);
    switch (lang) {
      case 'de':
        return 'Business-Abo aktivieren ($priceLine)';
      case 'en':
        return 'Activate business subscription ($priceLine)';
      case 'pl':
        return 'Aktywuj subskrypcję biznesową ($priceLine)';
      case 'es':
        return 'Activar suscripción comercial ($priceLine)';
      case 'fr':
        return 'Activer l\'abonnement professionnel ($priceLine)';
      case 'it':
        return 'Attiva abbonamento business ($priceLine)';
      case 'cs':
        return 'Aktivovat firemní předplatné ($priceLine)';
      case 'sv':
        return 'Aktivera företagsprenumeration ($priceLine)';
      case 'uk':
        return 'Активувати бізнес-підписку ($priceLine)';
      case 'ru':
        return 'Активировать бизнес-подписку ($priceLine)';
      case 'hi':
        return 'व्यावसायिक सदस्यता सक्रिय करें ($priceLine)';
      case 'id':
        return 'Aktifkan langganan bisnis ($priceLine)';
      case 'sw':
        return 'Washa usajili wa biashara ($priceLine)';
      case 'ar':
        return 'تفعيل اشتراك الأعمال ($priceLine)';
      case 'tr':
        return 'İş aboneliğini etkinleştir ($priceLine)';
      case 'sr':
        return 'Aktiviraj poslovnu licencu ($priceLine)';
      case 'bs':
        return 'Aktiviraj poslovnu licencu ($priceLine)';
      case 'zh':
        return '激活商业订阅（$priceLine）';
      case 'hr':
      default:
        return 'Aktiviraj poslovnu pretplatu ($priceLine)';
    }
  }

  static String _monthlyPeriodSuffix(String lang) {
    switch (lang) {
      case 'de':
        return ' / Monat';
      case 'en':
        return ' / mo';
      case 'pl':
        return ' / mies.';
      case 'es':
        return ' / mes';
      case 'fr':
        return ' / mois';
      case 'it':
        return ' / mese';
      case 'cs':
        return ' / měsíc';
      case 'sv':
        return ' / mån';
      case 'uk':
        return ' / міс.';
      case 'ru':
        return ' / мес.';
      case 'hi':
        return ' / माह';
      case 'id':
        return ' / bln';
      case 'sw':
        return ' / mwezi';
      case 'ar':
        return ' / شهر';
      case 'tr':
        return ' / ay';
      case 'sr':
        return ' / mj.';
      case 'zh':
        return ' / 月';
      case 'hr':
      case 'bs':
      default:
        return ' / mj.';
    }
  }

  static String _normalizeLanguage(String languageCode) {
    final lang = languageCode.toLowerCase();
    if (lang.startsWith('sr')) return 'sr';
    if (lang.startsWith('hr')) return 'hr';
    if (lang.startsWith('pl')) return 'pl';
    if (lang.startsWith('es')) return 'es';
    if (lang.startsWith('fr')) return 'fr';
    if (lang.startsWith('cs')) return 'cs';
    if (lang.startsWith('sv')) return 'sv';
    if (lang.startsWith('uk')) return 'uk';
    if (lang.startsWith('ru')) return 'ru';
    if (lang.startsWith('hi')) return 'hi';
    if (lang.startsWith('id')) return 'id';
    if (lang.startsWith('sw')) return 'sw';
    if (lang.startsWith('ar')) return 'ar';
    if (lang.startsWith('tr')) return 'tr';
    return lang;
  }

  static String _formatAmount(double amount, String currencyCode) {
    final code = CurrencyService.normalizeCode(currencyCode);
    final text = _formatNumber(amount);

    switch (code) {
      case CurrencyService.eur:
        return '$text €';
      case CurrencyService.bam:
        return '$text KM';
      case CurrencyService.rsd:
        return '$text RSD';
      case CurrencyService.cny:
        return '¥$text';
      case CurrencyService.sek:
        return '$text kr';
      case CurrencyService.uah:
        return '$text ₴';
      case CurrencyService.rub:
        return '$text ₽';
      case CurrencyService.inr:
        return '₹$text';
      case CurrencyService.idr:
        return 'Rp$text';
      case CurrencyService.kes:
        return 'KSh$text';
      case CurrencyService.sar:
        return '$text ر.س';
      case CurrencyService.aed:
        return '$text د.إ';
      case CurrencyService.egp:
        return '$text ج.م';
      case CurrencyService.mad:
        return '$text د.م.';
      case CurrencyService.qar:
        return '$text ر.ق';
      case CurrencyService.jod:
        return '$text د.أ';
      case CurrencyService.kwd:
        return '$text د.ك';
      case CurrencyService.omr:
        return '$text ر.ع.';
      case CurrencyService.bhd:
        return '$text د.ب';
      case CurrencyService.chf:
        return 'CHF $text';
      case CurrencyService.try_:
        return '$text ₺';
      case 'USD':
        return '\$$text';
      case 'GBP':
        return '£$text';
      case 'INR':
        return '₹$text';
      default:
        return '$text $code';
    }
  }

  static String _formatNumber(double amount) {
    final isWhole = amount == amount.roundToDouble() && amount >= 100;
    final fixed = isWhole
        ? amount.round().toString()
        : amount.toStringAsFixed(2);
    if (!fixed.contains('.')) {
      return fixed.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
    }
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$whole,${parts[1]}';
  }

  static double _convertFromEur(double eur, String currencyCode) {
    final code = CurrencyService.normalizeCode(currencyCode);
    switch (code) {
      case CurrencyService.eur:
        return eur;
      case CurrencyService.bam:
        return eur * CurrencyService.eurToBam;
      case CurrencyService.rsd:
        return eur * CurrencyService.eurToRsd;
      case CurrencyService.cny:
        return eur * CurrencyService.eurToCny;
      case CurrencyService.sek:
        return eur * CurrencyService.eurToSek;
      case CurrencyService.uah:
        return eur * CurrencyService.eurToUah;
      case CurrencyService.rub:
        return eur * CurrencyService.eurToRub;
      case CurrencyService.inr:
        return eur * CurrencyService.eurToInr;
      case CurrencyService.idr:
        return eur * CurrencyService.eurToIdr;
      case CurrencyService.kes:
        return eur * CurrencyService.eurToKes;
      case CurrencyService.sar:
        return eur * CurrencyService.eurToSar;
      case CurrencyService.aed:
        return eur * CurrencyService.eurToAed;
      case CurrencyService.egp:
        return eur * CurrencyService.eurToEgp;
      case CurrencyService.mad:
        return eur * CurrencyService.eurToMad;
      case CurrencyService.qar:
        return eur * CurrencyService.eurToQar;
      case CurrencyService.jod:
        return eur * CurrencyService.eurToJod;
      case CurrencyService.kwd:
        return eur * CurrencyService.eurToKwd;
      case CurrencyService.omr:
        return eur * CurrencyService.eurToOmr;
      case CurrencyService.bhd:
        return eur * CurrencyService.eurToBhd;
      case CurrencyService.chf:
        return SwissMarketPricing.chfAmount(eur);
      case CurrencyService.try_:
        return eur * CurrencyService.eurToTry;
      case 'USD':
        return eur * eurToUsd;
      case 'GBP':
        return eur * eurToGbp;
      case 'INR':
        return eur * CurrencyService.eurToInr;
      default:
        return eur;
    }
  }

  static String _currencyCodeForDevelopedCountry(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'US':
        return 'USD';
      case 'GB':
        return 'GBP';
      case 'CN':
        return CurrencyService.cny;
      case 'SE':
        return CurrencyService.sek;
      case 'JP':
      case 'AU':
      case 'CA':
      case 'NZ':
      case 'KR':
      case 'SG':
      case 'CH':
      case 'NO':
      default:
        return CurrencyService.eur;
    }
  }

  static double _pppFactorForCountry(String countryCode) {
    final code = countryCode.toUpperCase();
    if (_africaCountryCodes.contains(code)) return 0.35;
    if (_southAsiaCountryCodes.contains(code)) return 0.35;
    if (_latinAmericaCountryCodes.contains(code)) return 0.50;
    if (_southeastAsiaCountryCodes.contains(code)) return 0.45;
    return 0.50;
  }

  static Future<void> initialize() async {
    if (!PaymentConfig.isStripeConfigured) return;
    Stripe.publishableKey = PaymentConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
  }

  Future<PaymentResult?> processPayment({
    required BuildContext context,
    required CartPaymentMethod method,
    required double amount,
    required String currency,
    String? sellerId,
  }) async {
    if (!method.requiresDigitalProcessing) {
      return PaymentResult.cashPending();
    }

    try {
      switch (method) {
        case CartPaymentMethod.stripe:
        case CartPaymentMethod.googlePay:
          return await _stripeCheckoutService.processCardOrWalletPayment(
            context: context,
            method: method,
            amount: amount,
            currency: currency,
            sellerId: sellerId,
          );
        case CartPaymentMethod.paypal:
          return await _paypalCheckoutService.processPayPalPayment(
            context: context,
            amount: amount,
            currency: currency,
            sellerId: sellerId,
          );
        case CartPaymentMethod.cash:
        case CartPaymentMethod.directPaypal:
        case CartPaymentMethod.bankTransfer:
          return PaymentResult.cashPending();
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return null;
      rethrow;
    } on PaymentCancelledException {
      return null;
    }
  }

  static const Set<String> _euCountryCodes = {
    'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR',
    'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK',
    'SI', 'ES', 'SE', 'IS', 'LI', 'NO', 'CH',
  };

  static const Set<String> _developedCountryCodes = {
    'US', 'CA', 'GB', 'AU', 'NZ', 'JP', 'KR', 'SG', 'HK', 'TW', 'IL', 'AE',
    'SA', 'QA', 'KW', 'OM', 'BH',
  };

  static const Set<String> _africaCountryCodes = {
    'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CV', 'CM', 'CF', 'TD', 'KM', 'CG',
    'CD', 'CI', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GM', 'GH', 'GN',
    'GW', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ',
    'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD',
    'TZ', 'TG', 'TN', 'UG', 'ZM', 'ZW',
  };

  static const Set<String> _southAsiaCountryCodes = {
    'IN', 'PK', 'BD', 'NP', 'LK', 'AF',
  };

  static const Set<String> _southeastAsiaCountryCodes = {
    'ID', 'PH', 'VN', 'TH', 'MY', 'MM', 'KH', 'LA',
  };

  static const Set<String> _latinAmericaCountryCodes = {
    'MX', 'GT', 'HN', 'SV', 'NI', 'CR', 'PA', 'CO', 'VE', 'EC', 'PE', 'BO',
    'PY', 'CL', 'AR', 'UY', 'BR', 'DO', 'CU', 'HT', 'JM', 'TT',
  };
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

/// Dinamička regionalna cijena poslovne pretplate (GPS + valutna regija).
final companySubscriptionQuoteProvider =
    FutureProvider.family<CompanySubscriptionQuote, CompanyQuoteRequest>(
  (ref, request) async {
    return PaymentService().resolveCompanySubscriptionQuote(
      languageCode: request.languageCode,
      currencyRegion: request.currencyRegion,
    );
  },
);
