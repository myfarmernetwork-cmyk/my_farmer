import 'package:flutter/material.dart';

import '../../models/product.dart';

/// Two-column product grid with explicit cell sizes.
///
/// Prefer [buildSliver] inside [CustomScrollView] on storefront profiles.
/// The [build] method remains for scrollable parents that are not sliver-based.
class StorefrontProductGrid extends StatelessWidget {
  const StorefrontProductGrid({
    super.key,
    required this.products,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 16),
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 10,
    this.mainAxisSpacing = 10,
    this.childAspectRatio = 0.72,
  });

  final List<Product> products;
  final Widget Function(BuildContext context, Product product) itemBuilder;
  final EdgeInsets padding;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  SliverGridDelegate get _gridDelegate => SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      );

  /// Reliable grid for storefront [CustomScrollView] — same layout on all devices.
  Widget buildSliver(BuildContext context) {
    if (products.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, index) => itemBuilder(context, products[index]),
          childCount: products.length,
        ),
      ),
    );
  }

  double _resolveWidth(BuildContext context, BoxConstraints constraints) {
    if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
      return constraints.maxWidth;
    }
    return MediaQuery.sizeOf(context).width;
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = _resolveWidth(context, constraints);
        if (maxWidth <= 0) return const SizedBox.shrink();

        final innerWidth = maxWidth - padding.horizontal;
        final cellWidth =
            (innerWidth - crossAxisSpacing * (crossAxisCount - 1)) /
                crossAxisCount;
        final cellHeight = cellWidth / childAspectRatio;

        return Padding(
          padding: padding,
          child: Wrap(
            spacing: crossAxisSpacing,
            runSpacing: mainAxisSpacing,
            children: [
              for (final product in products)
                SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: itemBuilder(context, product),
                ),
            ],
          ),
        );
      },
    );
  }
}
