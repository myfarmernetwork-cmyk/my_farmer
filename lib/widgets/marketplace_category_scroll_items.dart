import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../utils/product_categories.dart';

/// Tip ikone u horizontalnoj traci kategorija.
enum MarketplaceCategoryIconType {
  fontAwesome,
  material,
  svg,
  png,
  seedlingWithOpenBag,
}

/// Jedna ikona kategorije — standardna ili SVG.
class MarketplaceCategoryScrollIconData {
  const MarketplaceCategoryScrollIconData.fontAwesome(
    this.icon, {
    this.fallback,
  })  : type = MarketplaceCategoryIconType.fontAwesome,
        svgAsset = null,
        materialIcon = null,
        pngAsset = null,
        pngScale = 1;

  const MarketplaceCategoryScrollIconData.material(this.materialIcon,
      {this.fallback})
      : type = MarketplaceCategoryIconType.material,
        svgAsset = null,
        icon = null,
        pngAsset = null,
        pngScale = 1;

  const MarketplaceCategoryScrollIconData.svg(this.svgAsset, {this.fallback})
      : type = MarketplaceCategoryIconType.svg,
        icon = null,
        materialIcon = null,
        pngAsset = null,
        pngScale = 1;

  /// Potvrđena PNG skica (npr. traktor bez kabine).
  const MarketplaceCategoryScrollIconData.png(
    this.pngAsset, {
    this.fallback,
    this.pngScale = 1,
  })  : type = MarketplaceCategoryIconType.png,
        icon = null,
        materialIcon = null,
        svgAsset = null;

  /// Klica (FA) + potvrđena PNG vreća lijevo.
  const MarketplaceCategoryScrollIconData.seedlingWithOpenBag(
    this.icon, {
    this.fallback,
  })  : type = MarketplaceCategoryIconType.seedlingWithOpenBag,
        svgAsset = null,
        materialIcon = null,
        pngAsset = null,
        pngScale = 1;

  final MarketplaceCategoryIconType type;
  final IconData? icon;
  final IconData? materialIcon;
  final String? svgAsset;
  final String? pngAsset;
  final double pngScale;
  final IconData? fallback;
}

/// Jedna kategorija u scroll traci (kod + ikona).
class MarketplaceCategoryScrollItem {
  const MarketplaceCategoryScrollItem({
    required this.code,
    required this.icon,
  });

  final String code;
  final MarketplaceCategoryScrollIconData icon;
}

/// Centralna lista kategorija — Font Awesome solid + SVG gdje treba.
abstract final class MarketplaceCategoryScrollCatalog {
  static const pesticideSvg = 'assets/icons/pesticide.svg';
  static const tractorOpenAsset = 'assets/icons/categories/tractor_open.png';

  static const items = <MarketplaceCategoryScrollItem>[
    MarketplaceCategoryScrollItem(
      code: ProductCategories.all,
      icon: MarketplaceCategoryScrollIconData.material(Icons.grid_view),
    ),
    MarketplaceCategoryScrollItem(
      code: ProductCategories.vegetables,
      icon: MarketplaceCategoryScrollIconData.fontAwesome(
        FontAwesomeIcons.carrot,
        fallback: Icons.eco,
      ),
    ),
    MarketplaceCategoryScrollItem(
      code: ProductCategories.fruit,
      icon: MarketplaceCategoryScrollIconData.fontAwesome(
        FontAwesomeIcons.appleWhole,
        fallback: Icons.apple,
      ),
    ),
    MarketplaceCategoryScrollItem(
      code: ProductCategories.cereals,
      icon: MarketplaceCategoryScrollIconData.fontAwesome(
        FontAwesomeIcons.wheatAwn,
        fallback: Icons.agriculture,
      ),
    ),
    MarketplaceCategoryScrollItem(
      code: ProductCategories.animals,
      icon: MarketplaceCategoryScrollIconData.fontAwesome(
        FontAwesomeIcons.cow,
        fallback: Icons.pets,
      ),
    ),
    MarketplaceCategoryScrollItem(
      code: ProductCategories.mechanization,
      icon: MarketplaceCategoryScrollIconData.png(
        tractorOpenAsset,
        fallback: Icons.agriculture,
        pngScale: 1.42,
      ),
    ),
    MarketplaceCategoryScrollItem(
      code: ProductCategories.fertilizersStimulants,
      icon: MarketplaceCategoryScrollIconData.seedlingWithOpenBag(
        FontAwesomeIcons.seedling,
        fallback: Icons.grass,
      ),
    ),
    MarketplaceCategoryScrollItem(
      code: ProductCategories.plantProtection,
      icon: MarketplaceCategoryScrollIconData.fontAwesome(
        FontAwesomeIcons.flask,
        fallback: Icons.biotech,
      ),
    ),
  ];

  static List<String> get codes =>
      items.map((item) => item.code).toList(growable: false);

  static MarketplaceCategoryScrollIconData iconFor(String code) {
    final normalized = ProductCategories.normalize(code);
    for (final item in items) {
      if (item.code == normalized) return item.icon;
    }
    return MarketplaceCategoryScrollIconData.material(
      ProductCategories.solidIconFor(code),
    );
  }
}
