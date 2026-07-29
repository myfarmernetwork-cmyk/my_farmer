import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';

/// Brzi prekidač dostupnosti na kartici prodavača.
/// Uključeno = artikal je dostupan; isključeno = [RASPRODANO] na tržnici.
class SellerProductAvailabilitySwitch extends ConsumerWidget {
  const SellerProductAvailabilitySwitch({
    super.key,
    required this.product,
    this.compact = true,
  });

  final Product product;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (product.isService) return const SizedBox.shrink();

    final isAvailable = !product.isSoldOut;

    final control = Switch.adaptive(
      value: isAvailable,
      activeColor: Colors.green.shade700,
      onChanged: (available) {
        ref.read(productRepositoryProvider).updateSoldOut(
              productId: product.id,
              isSoldOut: !available,
            );
      },
    );

    if (compact) {
      return Tooltip(
        message: isAvailable
            ? 'product_mark_available'.tr()
            : 'product_mark_sold_out'.tr(),
        child: control,
      );
    }

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        'product_mark_sold_out'.tr(),
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        isAvailable
            ? 'product_available_on_market'.tr()
            : 'product_hidden_on_market'.tr(),
        style: const TextStyle(fontSize: 12),
      ),
      value: isAvailable,
      activeColor: Colors.green.shade700,
      onChanged: (available) {
        ref.read(productRepositoryProvider).updateSoldOut(
              productId: product.id,
              isSoldOut: !available,
            );
      },
    );
  }
}
