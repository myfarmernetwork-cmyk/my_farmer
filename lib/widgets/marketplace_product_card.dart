import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../theme/agro_accent_colors.dart';
import 'harvest_countdown_overlay.dart';
import 'product_card.dart';
import 'product_sold_out_overlay.dart';

/// Kartica proizvoda na tržištu — puna slika, postepeni tamni overlay (bez blur-a).
class MarketplaceProductCard extends ConsumerWidget {
  const MarketplaceProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.distanceKm,
    this.onSellerTap,
    this.sellerEmoji = '🌾',
  });

  final Product product;
  final VoidCallback onTap;
  final double? distanceKm;
  final VoidCallback? onSellerTap;
  final String sellerEmoji;

  Widget _buildImage() {
    final image = Image.network(
      product.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        color: AgroAccentColors.glassMid,
        alignment: Alignment.center,
        child: Icon(
          product.isService ? Icons.build_outlined : Icons.image_outlined,
          color: AgroAccentColors.accent,
          size: 40,
        ),
      ),
    );

    Widget wrapped = image;
    if (product.isHarvestCountdownActive && product.harvestDateTime != null) {
      wrapped = HarvestCountdownOverlay(
        harvestDateTime: product.harvestDateTime!,
        isDelivery: product.isDeliveryUpcoming,
        upcomingMode: product.upcomingMode,
        dimPhoto: false,
        showBottomCountdown: false,
        child: image,
      );
    }

    return ProductSoldOutOverlay(
      show: product.isUnavailable,
      compact: true,
      child: wrapped,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = context.locale.languageCode;
    final category = product.categoryLabel(localeCode);
    final distanceLabel = distanceKm != null
        ? 'search_distance_km'.tr(
            namedArgs: {'km': distanceKm!.toStringAsFixed(1)},
          )
        : null;
    final sellerLabel = product.sellerName.trim().isEmpty
        ? 'Farmer'
        : product.sellerName.trim();
    final radius = AgroAccentColors.marketplaceCornerRadius;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AgroAccentColors.borderLight, width: 1),
            boxShadow: AgroAccentColors.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 1),
            child: AspectRatio(
              aspectRatio: AgroAccentColors.marketplaceProductCardAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AgroAccentColors.cardOverlayGradient,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            height: 1.15,
                            color: AgroAccentColors.cardTextLight,
                          ),
                        ),
                        const SizedBox(height: 3),
                        ProductCardPriceText(
                          price: product.price,
                          originalCurrency: product.originalCurrency,
                          unit: product.displayUnit,
                          style: const TextStyle(
                            color: AgroAccentColors.priceGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: onSellerTap,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            '$sellerEmoji $sellerLabel',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AgroAccentColors.cardTextLight
                                  .withValues(alpha: 0.88),
                              fontSize: 11,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AgroAccentColors.priceGreen
                                      .withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (distanceLabel != null)
                              Text(
                                distanceLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.lightBlue[200],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
