import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_units.dart';
import '../providers/locale_settings_provider.dart';
import '../services/currency_service.dart';
import 'product_sold_out_overlay.dart';

/// Slika proizvoda na kartici tržnice — s crvenim [RASPRODANO] overlayem.
class ProductCardImage extends StatelessWidget {
  const ProductCardImage({
    super.key,
    required this.isUnavailable,
    required this.child,
  });

  final bool isUnavailable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProductSoldOutOverlay(
      show: isUnavailable,
      child: child,
    );
  }
}

/// Cijena na kartici tržnice — lokalizirana valuta bez KM zagrada.
class ProductCardPriceText extends ConsumerWidget {
  const ProductCardPriceText({
    super.key,
    required this.price,
    this.originalCurrency = CurrencyService.bam,
    this.unit = 'kom',
    this.style,
  });

  final double price;
  final String originalCurrency;
  final String unit;
  final TextStyle? style;

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
    final amountText = CurrencyService().formatWithTranslatedCurrency(
      context,
      converted.displayAmount,
      currencyRegion: region,
      currencyCode: converted.displayCurrency,
    );
    final unitLabel = ProductUnits.shortLabel(
      ProductUnits.normalize(unit),
    );
    final unitSuffix = unitLabel.isEmpty ? '' : ' / $unitLabel';

    return Text(
      '$amountText$unitSuffix',
      style: style,
    );
  }
}
