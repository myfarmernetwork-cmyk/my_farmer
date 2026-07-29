import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

String productSoldOutBadgeText(BuildContext context) =>
    '[${'product_sold_out'.tr()}]';

class ProductSoldOutOverlay extends StatelessWidget {
  const ProductSoldOutOverlay({
    super.key,
    required this.show,
    required this.child,
  });

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (show)
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
