import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/arabic_market_pricing.dart';
import '../config/swiss_market_pricing.dart';
import '../providers/locale_settings_provider.dart';

/// Fixed EUR-based exchange rates for display conversion.
class CurrencyService {
  static const double eurToBam = 1.95583;
  static const double eurToSek = 11.20;
  static const double eurToUah = 43.0;
  static const double eurToRub = 98.0;
  static const double eurToInr = 92.0;
  static const double eurToIdr = 17000.0;
  static const double eurToKes = 145.0;
  static const double eurToSar = 4.05;
  static const double eurToAed = 4.0;
  static const double eurToEgp = 52.0;
  static const double eurToMad = 10.8;
  static const double eurToQar = 3.95;
  static const double eurToJod = 0.77;
  static const double eurToKwd = 0.33;
  static const double eurToOmr = 0.42;
  static const double eurToBhd = 0.41;
  static const double eurToChf = 0.95;
  static const double eurToCny = 7.85;
  static const double eurToRsd = 117.0;
  static const double eurToTry = 37.0;

  static const String bam = 'BAM';
  static const String eur = 'EUR';
  static const String sek = 'SEK';
  static const String uah = 'UAH';
  static const String rub = 'RUB';
  static const String inr = 'INR';
  static const String idr = 'IDR';
  static const String kes = 'KES';
  static const String sar = 'SAR';
  static const String aed = 'AED';
  static const String egp = 'EGP';
  static const String mad = 'MAD';
  static const String qar = 'QAR';
  static const String jod = 'JOD';
  static const String kwd = 'KWD';
  static const String omr = 'OMR';
  static const String bhd = 'BHD';
  static const String chf = 'CHF';
  static const String cny = 'CNY';
  static const String rsd = 'RSD';
  static const String try_ = 'TRY';

  /// Stripe zero-decimal currencies — minor unit equals major unit.
  static const Set<String> stripeZeroDecimalCurrencies = {
    'BIF', 'CLP', 'DJF', 'GNF', 'JPY', 'KMF', 'KRW', 'MGA', 'PYG', 'RWF',
    'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF', 'IDR',
  };

  /// Converts a display amount to Stripe minor units (cent-style integer).
  static int toStripeMinorUnits(double amount, String currency) {
    final raw = currency.trim().toUpperCase();
    if (stripeZeroDecimalCurrencies.contains(raw)) {
      return amount.round();
    }
    final code = normalizeCode(currency);
    if (stripeZeroDecimalCurrencies.contains(code)) {
      return amount.round();
    }
    return (amount * 100).round();
  }

  /// Euro valuta za jezike EU tržišta (hr, de, pl, es...).
  static bool isEuroLockedLanguage(Locale locale) {
    final lang = locale.languageCode.toLowerCase();
    return lang == 'hr' || lang == 'de' || lang == 'pl' || lang == 'es' || lang == 'fr' || lang == 'cs' || lang == 'it';
  }

  /// Kineski jezik uvijek prikazuje Yuan — neovisno o valuti u bazi ili regiji.
  static bool isCnyLockedLanguage(Locale locale) {
    return locale.languageCode.toLowerCase() == 'zh';
  }

  /// Švedski jezik uvijek prikazuje kune (SEK).
  static bool isSekLockedLanguage(Locale locale) {
    return locale.languageCode.toLowerCase() == 'sv';
  }

  /// Ukrajinski jezik uvijek prikazuje grivnu (UAH).
  static bool isUahLockedLanguage(Locale locale) {
    return locale.languageCode.toLowerCase() == 'uk';
  }

  /// Ruski jezik uvijek prikazuje rublj (RUB).
  static bool isRubLockedLanguage(Locale locale) {
    return locale.languageCode.toLowerCase() == 'ru';
  }

  /// Hindi jezik uvijek prikazuje indijsku rupiju (INR).
  static bool isInrLockedLanguage(Locale locale) {
    return locale.languageCode.toLowerCase() == 'hi';
  }

  /// Bahasa Indonesia uvijek prikazuje rupiah (IDR).
  static bool isIdrLockedLanguage(Locale locale) {
    return locale.languageCode.toLowerCase() == 'id';
  }

  /// Kiswahili uvijek prikazuje shilingi ya Kenya (KES).
  static bool isKesLockedLanguage(Locale locale) {
    return locale.languageCode.toLowerCase() == 'sw';
  }

  /// Arapski jezik — valuta prema GPS državi (SAR, AED, EGP...).
  static bool isSarLockedLanguage(Locale locale) {
    return locale.languageCode.toLowerCase() == 'ar';
  }

  /// Turski jezik uvijek prikazuje liru (TRY).
  static bool isTryLockedLanguage(Locale locale) {
    return locale.languageCode.toLowerCase() == 'tr';
  }

  /// Njemački/francuski/talijanski u Švicarskoj (GPS CH) — CHF umjesto EUR.
  static bool isSwissChfLockedLanguage(Locale locale) {
    final lang = locale.languageCode;
    if (lang != 'de' && lang != 'fr' && lang != 'it') {
      return false;
    }
    return _cachedDeviceCountryCode == 'CH';
  }

  static String? _cachedDeviceCountryCode;

  static void cacheDeviceCountryCode(String? code) {
    _cachedDeviceCountryCode =
        code == null || code.isEmpty ? null : code.toUpperCase();
  }

  static String resolveArabicCurrencyCode({String? countryCode}) {
    return ArabicMarketPricing.currencyCodeForCountry(
      countryCode ?? _cachedDeviceCountryCode,
    );
  }

  static String normalizeCode(String? code) {
    final value = (code ?? bam).trim().toUpperCase();
    switch (value) {
      case 'KM':
      case 'BAM':
        return bam;
      case 'EUR':
      case '€':
        return eur;
      case 'SEK':
      case 'KR':
        return sek;
      case 'UAH':
      case '₴':
      case 'ГРН':
        return uah;
      case 'RUB':
      case '₽':
      case 'РУБ':
        return rub;
      case 'INR':
      case '₹':
        return inr;
      case 'IDR':
      case 'RP':
        return idr;
      case 'KES':
      case 'KSH':
        return kes;
      case 'SAR':
      case 'SR':
      case 'ر.س':
        return sar;
      case 'CNY':
      case 'RMB':
      case '¥':
        return cny;
      case 'RSD':
        return rsd;
      case 'TRY':
      case '₺':
      case 'TL':
        return try_;
      default:
        return bam;
    }
  }

  String resolveBuyerCurrencyCode(
    Locale locale, {
    String? currencyRegion,
  }) {
    final lang = locale.languageCode.toLowerCase();

    if (isSwissChfLockedLanguage(locale)) {
      return chf;
    }

    // Valuta strogo prati odabrani jezik — regija ne smije nadjačati jezičnu valutu.
    if (isEuroLockedLanguage(locale)) {
      return eur;
    }
    if (lang == 'zh') {
      return cny;
    }
    if (lang == 'bs') {
      return bam;
    }
    if (lang == 'uk') {
      return uah;
    }
    if (lang == 'ru') {
      return rub;
    }
    if (lang == 'hi') {
      return inr;
    }
    if (lang == 'id') {
      return idr;
    }
    if (lang == 'sw') {
      return kes;
    }
    if (lang == 'ar') {
      return resolveArabicCurrencyCode();
    }
    if (lang == 'tr') {
      return try_;
    }

    if (currencyRegion != null && currencyRegion.isNotEmpty) {
      final fromRegion = _currencyCodeFromRegion(currencyRegion, locale);
      if (fromRegion != null) return fromRegion;
    }

    // Valuta strogo prati odabrani jezik cijele platforme.
    if (lang == 'sr') {
      if (currencyRegion == 'rs') return rsd;
      if (currencyRegion == 'bih') return bam;
      if (locale.countryCode == 'RS') {
        return rsd;
      }
      if (locale.countryCode == 'BA') {
        return bam;
      }
      return rsd;
    }
    if (lang == 'sv') {
      if (currencyRegion == 'se') return sek;
      if (currencyRegion == 'eu') return eur;
      return sek;
    }

    final bihRegion =
        currencyRegion == 'bih' || locale.countryCode == 'BA';
    if (bihRegion && (lang == 'hr' || lang == 'bs')) {
      return bam;
    }
    if (locale.countryCode == 'BA') {
      return bam;
    }
    if (currencyRegion == 'eu') {
      return eur;
    }

    switch (lang) {
      default:
        return eur;
    }
  }

  String? _currencyCodeFromRegion(String region, Locale locale) {
    switch (region) {
      case 'eu':
        return eur;
      case 'bih':
        return bam;
      case 'rs':
        return rsd;
      case 'se':
        return sek;
      case 'cn':
        return cny;
      case 'emerging':
        return _currencyCodeForEmergingLocale(locale);
      default:
        return null;
    }
  }

  String _currencyCodeForEmergingLocale(Locale locale) {
    switch (locale.languageCode.toLowerCase()) {
      case 'sw':
        return kes;
      case 'hi':
        return inr;
      case 'id':
        return idr;
      case 'ar':
        return sar;
      case 'uk':
        return uah;
      case 'ru':
        return rub;
      default:
        return eur;
    }
  }

  /// ISO država → prikaz valute (GPS standard zemlje boravka).
  String currencyCodeFromCountry(String countryCode) {
    final code = countryCode.toUpperCase();
    switch (code) {
      case 'BA':
        return bam;
      case 'RS':
        return rsd;
      case 'SE':
        return sek;
      case 'KE':
        return kes;
      case 'IN':
        return inr;
      case 'ID':
        return idr;
      case 'UA':
        return uah;
      case 'RU':
        return rub;
      case 'CN':
        return cny;
      case 'TR':
        return try_;
      case 'US':
        return 'USD';
      case 'GB':
        return 'GBP';
      default:
        if (ArabicMarketPricing.arabCountries.contains(code)) {
          return ArabicMarketPricing.currencyCodeForCountry(code);
        }
        return eur;
    }
  }

  String resolveSellerCurrencyCode({
    String? currencyRegion,
    Locale? locale,
  }) {
    // Ista valuta koju prodavač vidi u formi (npr. € za hr u EU) — inače se
    // 3 € pogrešno spremi kao 3 KM, a kupac vidi ~1,53 € nakon konverzije.
    if (locale != null) {
      return resolveBuyerCurrencyCode(locale, currencyRegion: currencyRegion);
    }
    if (currencyRegion == 'bih' || currencyRegion == 'rs') return bam;
    if (currencyRegion == 'se') return sek;
    if (currencyRegion == 'eu') return eur;
    return eur;
  }

  double convertAmount(
    double amount,
    String fromCode,
    String toCode,
  ) {
    final from = normalizeCode(fromCode);
    final to = normalizeCode(toCode);
    if (from == to) return amount;

    final inEur = _toEur(amount, from);
    return _fromEur(inEur, to);
  }

  double _toEur(double amount, String from) {
    switch (from) {
      case eur:
        return amount;
      case bam:
        return amount / eurToBam;
      case sek:
        return amount / eurToSek;
      case uah:
        return amount / eurToUah;
      case rub:
        return amount / eurToRub;
      case inr:
        return amount / eurToInr;
      case idr:
        return amount / eurToIdr;
      case kes:
        return amount / eurToKes;
      case sar:
        return amount / eurToSar;
      case aed:
        return amount / eurToAed;
      case egp:
        return amount / eurToEgp;
      case mad:
        return amount / eurToMad;
      case qar:
        return amount / eurToQar;
      case jod:
        return amount / eurToJod;
      case kwd:
        return amount / eurToKwd;
      case omr:
        return amount / eurToOmr;
      case bhd:
        return amount / eurToBhd;
      case chf:
        return amount / SwissMarketPricing.swissPremiumRatio;
      case cny:
        return amount / eurToCny;
      case rsd:
        return amount / eurToRsd;
      case try_:
        return amount / eurToTry;
      default:
        return amount;
    }
  }

  double _fromEur(double amount, String to) {
    switch (to) {
      case eur:
        return amount;
      case bam:
        return amount * eurToBam;
      case sek:
        return amount * eurToSek;
      case uah:
        return amount * eurToUah;
      case rub:
        return amount * eurToRub;
      case inr:
        return amount * eurToInr;
      case idr:
        return amount * eurToIdr;
      case kes:
        return amount * eurToKes;
      case sar:
        return amount * eurToSar;
      case aed:
        return amount * eurToAed;
      case egp:
        return amount * eurToEgp;
      case mad:
        return amount * eurToMad;
      case qar:
        return amount * eurToQar;
      case jod:
        return amount * eurToJod;
      case kwd:
        return amount * eurToKwd;
      case omr:
        return amount * eurToOmr;
      case bhd:
        return amount * eurToBhd;
      case chf:
        return SwissMarketPricing.chfAmount(amount);
      case cny:
        return amount * eurToCny;
      case rsd:
        return amount * eurToRsd;
      case try_:
        return amount * eurToTry;
      default:
        return amount;
    }
  }

  ConvertedPrice convertForBuyer({
    required double amountInOriginal,
    required String originalCurrency,
    required Locale locale,
    String? currencyRegion,
  }) {
    final original = normalizeCode(originalCurrency);

    if (isSwissChfLockedLanguage(locale)) {
      final displayAmount = convertAmount(amountInOriginal, original, chf);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: chf,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (isCnyLockedLanguage(locale)) {
      final displayAmount = convertAmount(amountInOriginal, original, cny);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: cny,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (isEuroLockedLanguage(locale)) {
      final displayAmount = convertAmount(amountInOriginal, original, eur);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: eur,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (isSekLockedLanguage(locale)) {
      final buyer =
          resolveBuyerCurrencyCode(locale, currencyRegion: currencyRegion);
      final displayAmount = convertAmount(amountInOriginal, original, buyer);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: buyer,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (isUahLockedLanguage(locale)) {
      final displayAmount = convertAmount(amountInOriginal, original, uah);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: uah,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (isRubLockedLanguage(locale)) {
      final displayAmount = convertAmount(amountInOriginal, original, rub);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: rub,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (isInrLockedLanguage(locale)) {
      final displayAmount = convertAmount(amountInOriginal, original, inr);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: inr,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (isIdrLockedLanguage(locale)) {
      final displayAmount = convertAmount(amountInOriginal, original, idr);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: idr,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (isKesLockedLanguage(locale)) {
      final displayAmount = convertAmount(amountInOriginal, original, kes);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: kes,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (isSarLockedLanguage(locale)) {
      final buyer = resolveArabicCurrencyCode();
      final displayAmount = convertAmount(amountInOriginal, original, buyer);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: buyer,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (isTryLockedLanguage(locale)) {
      final displayAmount = convertAmount(amountInOriginal, original, try_);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: try_,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    if (locale.languageCode == 'sr') {
      final buyer =
          resolveBuyerCurrencyCode(locale, currencyRegion: currencyRegion);
      var source = original;
      // Tržnica: cijene su u KM (BAM); legacy zapisi pogrešno označeni kao RSD.
      if (buyer == rsd && (original == rsd || original == bam)) {
        source = bam;
      } else if (buyer == bam && original == rsd) {
        source = bam;
      }
      final displayAmount = convertAmount(amountInOriginal, source, buyer);
      return ConvertedPrice(
        displayAmount: displayAmount,
        displayCurrency: buyer,
        originalAmount: amountInOriginal,
        originalCurrency: original,
        showOriginal: false,
      );
    }

    final buyer = resolveBuyerCurrencyCode(locale, currencyRegion: currencyRegion);
    final displayAmount = convertAmount(amountInOriginal, original, buyer);

    return ConvertedPrice(
      displayAmount: displayAmount,
      displayCurrency: buyer,
      originalAmount: amountInOriginal,
      originalCurrency: original,
      showOriginal: false,
    );
  }

  String formatAmount(double amount, String currencyCode) {
    final code = normalizeCode(currencyCode);
    final text = _formatNumber(amount);

    switch (code) {
      case eur:
        return '$text €';
      case sek:
        return '$text kr';
      case uah:
        return '$text ₴';
      case rub:
        return '$text ₽';
      case inr:
        return '₹$text';
      case idr:
        return 'Rp$text';
      case kes:
        return 'KSh$text';
      case sar:
        return '$text ر.س';
      case aed:
        return '$text د.إ';
      case egp:
        return '$text ج.م';
      case mad:
        return '$text د.م.';
      case qar:
        return '$text ر.ق';
      case jod:
        return '$text د.أ';
      case kwd:
        return '$text د.ك';
      case omr:
        return '$text ر.ع.';
      case bhd:
        return '$text د.ب';
      case chf:
        return 'CHF $text';
      case cny:
        return '¥$text';
      case rsd:
        return '$text RSD';
      case try_:
        return '$text ₺';
      case bam:
      default:
        return '$text KM';
    }
  }

  /// Prikaz cijene s lokaliziranim simbolom iz assets/translations (ključ [currency]).
  String formatWithTranslatedCurrency(
    BuildContext context,
    double amount, {
    String? currencyRegion,
    String? currencyCode,
  }) {
    final text = _formatNumber(amount);
    final code = currencyCode ??
        resolveBuyerCurrencyCode(
          context.locale,
          currencyRegion: currencyRegion,
        );
    final symbol = 'currency'.tr();
    if (symbol != 'currency' && _currencyTrMatchesCode(symbol, code)) {
      if (symbol == '¥') return '¥$text';
      if (symbol == '€') return '$text €';
      if (symbol == '₴') return '$text ₴';
      if (symbol == '₽') return '$text ₽';
      if (symbol == '₹') return '₹$text';
      if (symbol == 'Rp') return 'Rp$text';
      if (symbol == 'KSh') return 'KSh$text';
      if (symbol == 'ر.س') return '$text $symbol';
      if (symbol == '₺') return '$text ₺';
      return '$text $symbol';
    }
    return formatAmount(amount, code);
  }

  bool _currencyTrMatchesCode(String translated, String code) {
    final normalized = normalizeCode(code);
    switch (normalized) {
      case rsd:
        return translated.toUpperCase().contains('RSD');
      case bam:
        return translated.toUpperCase().contains('KM');
      case eur:
        return translated.contains('€');
      case sek:
        return translated.toUpperCase().contains('SEK') ||
            translated.toUpperCase().contains('KR');
      default:
        return true;
    }
  }

  String formatDualWithTranslatedCurrency(
    BuildContext context,
    ConvertedPrice price, {
    String? currencyRegion,
  }) {
    return formatWithTranslatedCurrency(
      context,
      price.displayAmount,
      currencyRegion: currencyRegion,
      currencyCode: price.displayCurrency,
    );
  }

  String formatDual(ConvertedPrice price) {
    final primary = formatAmount(price.displayAmount, price.displayCurrency);
    if (!price.showOriginal) return primary;
    final secondary =
        formatAmount(price.originalAmount, price.originalCurrency);
    return '$primary (~ $secondary)';
  }

  ConvertedPrice convertCartTotal({
    required List<({double lineTotal, String originalCurrency})> lines,
    required Locale locale,
    String? currencyRegion,
  }) {
    if (lines.isEmpty) {
      return ConvertedPrice(
        displayAmount: 0,
        displayCurrency: resolveBuyerCurrencyCode(locale, currencyRegion: currencyRegion),
        originalAmount: 0,
        originalCurrency: bam,
        showOriginal: false,
      );
    }

    final buyer = resolveBuyerCurrencyCode(locale, currencyRegion: currencyRegion);
    var displaySum = 0.0;
    String? commonOriginal;
    var mixedOriginal = false;
    var originalSum = 0.0;

    for (final line in lines) {
      final original = normalizeCode(line.originalCurrency);
      displaySum += convertAmount(line.lineTotal, original, buyer);

      if (commonOriginal == null) {
        commonOriginal = original;
      } else if (commonOriginal != original) {
        mixedOriginal = true;
      }

      if (!mixedOriginal && commonOriginal == original) {
        originalSum += line.lineTotal;
      }
    }

    final showOriginal =
        !mixedOriginal && commonOriginal != null && commonOriginal != buyer;

    return ConvertedPrice(
      displayAmount: displaySum,
      displayCurrency: buyer,
      originalAmount: showOriginal ? originalSum : 0,
      originalCurrency: commonOriginal ?? buyer,
      showOriginal: showOriginal,
    );
  }

  String _formatNumber(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0];
    final fraction = parts[1];
    final withThousands = whole.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$withThousands,$fraction';
  }

  // --- Legacy helpers used elsewhere in the app ---

  CurrencyInfo resolve(
    Locale locale, {
    String? currencyRegion,
  }) {
    final code = resolveBuyerCurrencyCode(locale, currencyRegion: currencyRegion);
    return CurrencyInfo.fromCode(code);
  }

  String formatPrice(
    double amount,
    Locale locale, {
    String? currencyRegion,
  }) {
    final code = resolveBuyerCurrencyCode(locale, currencyRegion: currencyRegion);
    return formatAmount(amount, code);
  }
}

class ConvertedPrice {
  final double displayAmount;
  final String displayCurrency;
  final double originalAmount;
  final String originalCurrency;
  final bool showOriginal;

  const ConvertedPrice({
    required this.displayAmount,
    required this.displayCurrency,
    required this.originalAmount,
    required this.originalCurrency,
    required this.showOriginal,
  });
}

class CurrencyInfo {
  final String code;
  final String symbol;

  const CurrencyInfo({required this.code, required this.symbol});

  factory CurrencyInfo.fromCode(String code) {
    switch (CurrencyService.normalizeCode(code)) {
      case CurrencyService.eur:
        return const CurrencyInfo(code: 'EUR', symbol: '€');
      case CurrencyService.sek:
        return const CurrencyInfo(code: 'SEK', symbol: 'kr');
      case CurrencyService.uah:
        return const CurrencyInfo(code: 'UAH', symbol: '₴');
      case CurrencyService.rub:
        return const CurrencyInfo(code: 'RUB', symbol: '₽');
      case CurrencyService.inr:
        return const CurrencyInfo(code: 'INR', symbol: '₹');
      case CurrencyService.idr:
        return const CurrencyInfo(code: 'IDR', symbol: 'Rp');
      case CurrencyService.kes:
        return const CurrencyInfo(code: 'KES', symbol: 'KSh');
      case CurrencyService.sar:
        return const CurrencyInfo(code: 'SAR', symbol: 'ر.س');
      case CurrencyService.aed:
        return const CurrencyInfo(code: 'AED', symbol: 'د.إ');
      case CurrencyService.egp:
        return const CurrencyInfo(code: 'EGP', symbol: 'ج.م');
      case CurrencyService.mad:
        return const CurrencyInfo(code: 'MAD', symbol: 'د.م.');
      case CurrencyService.qar:
        return const CurrencyInfo(code: 'QAR', symbol: 'ر.ق');
      case CurrencyService.jod:
        return const CurrencyInfo(code: 'JOD', symbol: 'د.أ');
      case CurrencyService.kwd:
        return const CurrencyInfo(code: 'KWD', symbol: 'د.ك');
      case CurrencyService.omr:
        return const CurrencyInfo(code: 'OMR', symbol: 'ر.ع.');
      case CurrencyService.bhd:
        return const CurrencyInfo(code: 'BHD', symbol: 'د.ب');
      case CurrencyService.chf:
        return const CurrencyInfo(code: 'CHF', symbol: 'CHF');
      case CurrencyService.cny:
        return const CurrencyInfo(code: 'CNY', symbol: '¥');
      case CurrencyService.rsd:
        return const CurrencyInfo(code: 'RSD', symbol: 'RSD');
      case CurrencyService.try_:
        return const CurrencyInfo(code: 'TRY', symbol: '₺');
      case CurrencyService.bam:
      default:
        return const CurrencyInfo(code: 'BAM', symbol: 'KM');
    }
  }

  String format(double amount) {
    return CurrencyService().formatAmount(amount, code);
  }
}

final currencyServiceProvider = Provider<CurrencyService>(
  (ref) => CurrencyService(),
);

extension LocalizedCurrency on BuildContext {
  CurrencyInfo get currencyInfo {
    final region = ProviderScope.containerOf(this, listen: false)
        .read(currencyRegionProvider);
    return CurrencyService().resolve(locale, currencyRegion: region);
  }

  String formatPrice(double amount) {
    final region = ProviderScope.containerOf(this, listen: false)
        .read(currencyRegionProvider);
    return CurrencyService()
        .formatPrice(amount, locale, currencyRegion: region);
  }
}
