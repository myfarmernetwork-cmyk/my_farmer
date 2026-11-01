import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/product_categories.dart';

/// Ikone kategorija — solid (Material filled) ili outline (potvrđene skice PNG).
class MarketplaceCategoryIcon extends StatelessWidget {
  const MarketplaceCategoryIcon({
    super.key,
    required this.categoryCode,
    required this.color,
    this.size = 32,
    this.solid = false,
  });

  final String categoryCode;
  final Color color;
  final double size;
  final bool solid;

  static String assetFor(String code) {
    switch (ProductCategories.normalize(code)) {
      case ProductCategories.all:
        return 'assets/icons/categories/all.svg';
      case ProductCategories.vegetables:
        return 'assets/icons/categories/modern/vegetables.png';
      case ProductCategories.fruit:
        return 'assets/icons/categories/modern/fruit.png';
      case ProductCategories.cereals:
        return 'assets/icons/categories/modern/cereals.png';
      case ProductCategories.animals:
        return 'assets/icons/categories/modern/animals.png';
      case ProductCategories.mechanization:
        return 'assets/icons/categories/modern/mechanization.png';
      case ProductCategories.fertilizersStimulants:
        return 'assets/icons/categories/modern/fertilizers_stimulants.png';
      case ProductCategories.plantProtection:
        return 'assets/icons/categories/modern/plant_protection.png';
      default:
        return 'assets/icons/categories/all.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (solid) {
      return Icon(
        ProductCategories.solidIconFor(categoryCode),
        size: size,
        color: color,
      );
    }

    final asset = assetFor(categoryCode);
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
