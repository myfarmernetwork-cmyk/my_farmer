import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'marketplace_category_scroll_items.dart';

/// Dinamičko renderiranje: SvgPicture / Material / Font Awesome / kompozit.
class MarketplaceCategoryScrollIcon extends StatelessWidget {
  const MarketplaceCategoryScrollIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 32,
  });

  final MarketplaceCategoryScrollIconData icon;
  final Color color;
  final double size;

  Widget _materialIcon(IconData data) {
    return Icon(data, size: size, color: color);
  }

  Widget _fontAwesomeIcon(IconData data) {
    return FaIcon(data, size: size, color: color);
  }

  Widget _fallbackWidget(IconData data) {
    return _materialIcon(data);
  }

  Widget _fontAwesomeIconSized(IconData data, double iconSize) {
    return FaIcon(data, size: iconSize, color: color);
  }

  Widget _pngIcon(String asset, {IconData? fallback, double scale = 1}) {
    final iconSize = size * scale;
    return Image.asset(
      asset,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) {
        if (fallback != null) return _materialIcon(fallback);
        return _materialIcon(Icons.category);
      },
    );
  }

  /// Potvrđena skica vreće — PNG bez pozadine (iz skice, isti motiv).
  static const fertilizerBagAsset =
      'assets/icons/categories/fertilizers_bag.png';

  /// Biljka (malo manja) + potvrđena PNG vreća lijevo.
  Widget _seedlingWithOpenBag(IconData seedling) {
    return SizedBox(
      height: size * 1.12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Image.asset(
            fertilizerBagAsset,
            width: size * 1.75,
            height: size * 1.12,
            fit: BoxFit.contain,
            color: color,
            colorBlendMode: BlendMode.srcIn,
            filterQuality: FilterQuality.high,
          ),
          SizedBox(width: size * 0.01),
          _fontAwesomeIconSized(seedling, size * 0.55),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (icon.type) {
      case MarketplaceCategoryIconType.svg:
        return SvgPicture.asset(
          icon.svgAsset!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          placeholderBuilder: (_) {
            final fallback = icon.fallback;
            if (fallback != null) return _fallbackWidget(fallback);
            return SizedBox(width: size, height: size);
          },
          errorBuilder: (_, __, ___) {
            final fallback = icon.fallback;
            if (fallback != null) return _fallbackWidget(fallback);
            return _materialIcon(Icons.category);
          },
        );
      case MarketplaceCategoryIconType.seedlingWithOpenBag:
        return _seedlingWithOpenBag(icon.icon!);
      case MarketplaceCategoryIconType.png:
        return _pngIcon(
          icon.pngAsset!,
          fallback: icon.fallback,
          scale: icon.pngScale,
        );
      case MarketplaceCategoryIconType.fontAwesome:
        return _fontAwesomeIcon(icon.icon!);
      case MarketplaceCategoryIconType.material:
        return _materialIcon(icon.materialIcon!);
    }
  }
}
