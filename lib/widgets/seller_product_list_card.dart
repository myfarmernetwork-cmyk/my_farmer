import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../theme/agro_accent_colors.dart';
import '../utils/production_types.dart';
import 'product_price_text.dart';
import 'product_sold_out_overlay.dart';
import 'seller_product_availability_switch.dart';

/// Kartica proizvoda na ekranu Proizvodi — staklo na tamnozelenoj (Trgovina stil).
class SellerProductListCard extends ConsumerWidget {
  const SellerProductListCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    this.highlighted = false,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool highlighted;

  static const _radius = AgroAccentColors.marketplaceCornerRadius;
  static const _thumbSize = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeLabel = product.isService
        ? 'seller_service_label'.tr()
        : ProductionTypes.label(
            ProductionTypes.normalize(product.productionType),
          );

    final chipGreen = AgroAccentColors.marketplaceChipGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        color: chipGreen,
        border: Border.all(
          color: highlighted
              ? Colors.orange.shade400
              : Colors.white.withValues(alpha: 0.20),
          width: highlighted ? 1.8 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          width: _thumbSize,
                          height: _thumbSize,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                        )
                      : _thumbPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ProductPriceText(
                    price: product.price,
                    originalCurrency: product.originalCurrency,
                    unit: product.displayUnit,
                    style: const TextStyle(
                      color: Color(0xFFFFEB3B),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  if (product.isUnavailable) ...[
                    const SizedBox(height: 6),
                    _StatusPill(
                      label: productSoldOutBadgeText(context),
                      color: Colors.red.shade300,
                      background: Colors.red.withValues(alpha: 0.22),
                    ),
                  ] else if (product.isHarvestCountdownActive) ...[
                    const SizedBox(height: 6),
                    _StatusPill(
                      label: product.isDeliveryUpcoming
                          ? 'product_upcoming_delivery_badge'.tr()
                          : 'product_upcoming_badge'.tr(),
                      color: Colors.orange.shade200,
                      background: Colors.orange.withValues(alpha: 0.22),
                    ),
                  ],
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SellerProductAvailabilitySwitch(product: product),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Colors.white.withValues(alpha: 0.96),
                    ),
                    tooltip: 'common_edit'.tr(),
                    onPressed: onEdit,
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.white.withValues(alpha: 0.96),
                    ),
                    color: Colors.white,
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'animals_delete'.tr(),
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ],
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
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: _thumbSize,
      height: _thumbSize,
      color: Colors.white.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Icon(
        product.isService ? Icons.build_rounded : Icons.image_outlined,
        color: Colors.white.withValues(alpha: 0.88),
        size: 28,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
