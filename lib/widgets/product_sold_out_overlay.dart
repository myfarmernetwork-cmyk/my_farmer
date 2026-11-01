import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

String productSoldOutBadgeText(BuildContext context) => 'product_sold_out'.tr();

class ProductSoldOutOverlay extends StatelessWidget {
  const ProductSoldOutOverlay({
    super.key,
    required this.show,
    required this.child,
    this.compact = false,
  });

  final bool show;
  final Widget child;

  /// Na trgovini: lagani dim + badge gore — tekst i cijena ostaju čitljivi.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (show && compact) ...[
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.shade700.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.1,
                  ),
                ),
                child: Text(
                  productSoldOutBadgeText(context),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
        ] else if (show)
          Positioned.fill(
            child: Container(
              color: Colors.red.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.red.shade700.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  productSoldOutBadgeText(context),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
