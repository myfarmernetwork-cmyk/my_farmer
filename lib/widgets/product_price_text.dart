import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_units.dart';
import '../providers/locale_settings_provider.dart';
import '../services/currency_service.dart';

class ProductPriceText extends ConsumerWidget {
  final double price;
  final String originalCurrency;
  final String unit;
  final String? unitDescription;
  final TextStyle? style;
  final TextStyle? secondaryStyle;

  const ProductPriceText({
    super.key,
    required this.price,
    this.originalCurrency = CurrencyService.bam,
    this.unit = 'kom',
    this.unitDescription,
    this.style,
    this.secondaryStyle,
  });

  static ConvertedPrice convertedPrice(
    BuildContext context,
    WidgetRef ref,
    double price, {
    String originalCurrency = CurrencyService.bam,
  }) {
    ref.watch(currencyRegionProvider);
    final region = ref.read(currencyRegionProvider);
    return CurrencyService().convertForBuyer(
      amountInOriginal: price,
      originalCurrency: originalCurrency,
      locale: context.locale,
      currencyRegion: region,
    );
  }

  static String format(
    BuildContext context,
    WidgetRef ref,
    double price, {
    String originalCurrency = CurrencyService.bam,
    String unit = 'kom',
    String? unitDescription,
  }) {
    final converted = convertedPrice(
      context,
      ref,
      price,
      originalCurrency: originalCurrency,
    );
    final region = ref.read(currencyRegionProvider);
    final amountText = CurrencyService()
        .formatDualWithTranslatedCurrency(
      context,
      converted,
      currencyRegion: region,
    );
    final normalizedUnit = ProductUnits.normalize(unit);
    if (normalizedUnit.isEmpty) return amountText;

    final unitLabel = ProductUnits.shortLabel(normalizedUnit);
    final description = unitDescription?.trim();
    if (ProductUnits.isPak(normalizedUnit) &&
        description != null &&
        description.isNotEmpty) {
      return '$amountText / $unitLabel ($description)';
    }

    return '$amountText / $unitLabel';
  }

  static String formatAmountOnly(
    BuildContext context,
    WidgetRef ref,
    double price, {
    String originalCurrency = CurrencyService.bam,
  }) {
    final converted = convertedPrice(
      context,
      ref,
      price,
      originalCurrency: originalCurrency,
    );
    return CurrencyService().formatDualWithTranslatedCurrency(
      context,
      converted,
      currencyRegion: ref.read(currencyRegionProvider),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currencyRegionProvider);
    final region = ref.read(currencyRegionProvider);
    final converted = CurrencyService().convertForBuyer(
      amountInOriginal: price,
      originalCurrency: originalCurrency,
      locale: context.locale,
      currencyRegion: region,
    );
    final service = CurrencyService();
    final primary = service.formatWithTranslatedCurrency(
      context,
      converted.displayAmount,
      currencyRegion: region,
      currencyCode: converted.displayCurrency,
    );
    final normalizedUnit = ProductUnits.normalize(unit);
    final unitSuffix = normalizedUnit.isEmpty
        ? ''
        : ' / ${ProductUnits.shortLabel(normalizedUnit)}';
    final description = unitDescription?.trim();
    final pakSuffix = ProductUnits.isPak(normalizedUnit) &&
            description != null &&
            description.isNotEmpty
        ? ' ($description)'
        : '';

    return Text(
      '$primary$unitSuffix$pakSuffix',
      style: style,
    );
  }
}
