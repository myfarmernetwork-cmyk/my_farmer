import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../theme/agro_accent_colors.dart';

/// Brzi prekidač dostupnosti na kartici prodavača.
/// Slobodno = bijeli track + tamnozeleni thumb; rasprodano = nježno crveni track + isti zeleni thumb.
class SellerProductAvailabilitySwitch extends ConsumerWidget {
  const SellerProductAvailabilitySwitch({
    super.key,
    required this.product,
    this.compact = true,
  });

  final Product product;
  final bool compact;

  static const _chipGreen = AgroAccentColors.marketplaceChipGreen;
  static const _soldOutTrack = Color(0xFFE57373);
  static const _trackWidth = 46.0;
  static const _trackHeight = 26.0;
  static const _thumbSize = 20.0;
  static const _trackPadding = 3.0;

  Widget _buildSwitch({
    required bool isAvailable,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      toggled: isAvailable,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!isAvailable),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: _trackWidth,
          height: _trackHeight,
          padding: const EdgeInsets.all(_trackPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            color: isAvailable ? Colors.white : _soldOutTrack,
            border: Border.all(
              color: isAvailable
                  ? _chipGreen.withValues(alpha: 0.35)
                  : _soldOutTrack.withValues(alpha: 0.85),
              width: 0.8,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment:
                isAvailable ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: _thumbSize,
              height: _thumbSize,
              decoration: const BoxDecoration(
                color: _chipGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (product.isService) return const SizedBox.shrink();

    final isAvailable = !product.isSoldOut;

    void onChanged(bool available) {
      ref.read(productRepositoryProvider).updateSoldOut(
            productId: product.id,
            isSoldOut: !available,
          );
    }

    final control = _buildSwitch(
      isAvailable: isAvailable,
      onChanged: onChanged,
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
      onChanged: onChanged,
    );
  }
}
