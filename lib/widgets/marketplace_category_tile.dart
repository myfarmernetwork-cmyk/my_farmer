import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/agro_accent_colors.dart';
import '../utils/product_categories.dart';
import 'marketplace_category_icons.dart';

/// Jednake pločice kategorija — bijele outline ikone na staklu (premium mockup).
class MarketplaceCategoryTile extends StatelessWidget {
  const MarketplaceCategoryTile({
    super.key,
    required this.categoryCode,
    required this.isSelected,
    required this.onTap,
    this.compactGrid = false,
  });

  final String categoryCode;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compactGrid;

  static const tileHeight = 105.0;
  static const tileSize = tileHeight;
  static const gridTileSize = 96.0;
  static const scrollIconSize = 32.0;
  static const scrollLabelSize = 13.0;
  /// Maks. širina natpisa u scroll traci — omogućuje prelom u 2 reda bez smanjivanja fonta.
  static const scrollLabelMaxWidth = 136.0;
  static const radius = AgroAccentColors.marketplaceCornerRadius;

  @override
  Widget build(BuildContext context) {
    final label = ProductCategories.label(categoryCode);

    final selectedFill = Colors.white.withValues(alpha: 0.96);
    final inactiveFill = Colors.white.withValues(alpha: 0.13);
    final textColor =
        isSelected ? AgroAccentColors.forestGreen : Colors.white;
    final iconColor =
        isSelected ? AgroAccentColors.forestGreen : Colors.white;

    final height = compactGrid ? gridTileSize : tileHeight;
    final iconSize = compactGrid ? 32.0 : scrollIconSize;
    final labelSize = compactGrid ? 11.0 : scrollLabelSize;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          width: compactGrid ? double.infinity : null,
          padding: compactGrid
              ? const EdgeInsets.fromLTRB(4, 6, 4, 4)
              : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: isSelected ? selectedFill : inactiveFill,
            border: Border.all(
              color: isSelected
                  ? AgroAccentColors.forestGreen.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.30),
              width: isSelected ? 1.2 : 0.9,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              MarketplaceCategoryIcon(
                categoryCode: categoryCode,
                color: iconColor,
                size: iconSize,
              ),
              SizedBox(height: compactGrid ? 6 : 4),
              if (compactGrid)
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: labelSize,
                        height: 1.15,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: scrollLabelMaxWidth,
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: labelSize,
                      height: 1.15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return tile;
  }
}

/// 3×3 kvadratni grid kategorija u staklenoj ploči (mockup referenca).
class MarketplaceCategoryGrid extends StatelessWidget {
  const MarketplaceCategoryGrid({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  static const _gap = 8.0;
  static const _panelPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MarketplaceCategoryTile.radius),
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(_panelPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = (constraints.maxWidth - _gap * 2) / 3;
          final gridHeight = cell * 3 + _gap * 2;

          return SizedBox(
            height: gridHeight,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: _gap,
                mainAxisSpacing: _gap,
                childAspectRatio: 1,
              ),
              itemCount: ProductCategories.gridFilterCodes.length,
              itemBuilder: (context, index) {
                final code = ProductCategories.gridFilterCodes[index];
                if (code == null) {
                  return const SizedBox.shrink();
                }
                return MarketplaceCategoryTile(
                  categoryCode: code,
                  isSelected: selectedCategory == code,
                  compactGrid: true,
                  onTap: () => onCategorySelected(code),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Veterinari na karti — pilula s minijaturom karte i pinom desno (mockup).
class MarketplaceVetMapTile extends StatelessWidget {
  const MarketplaceVetMapTile({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  static const radius = AgroAccentColors.marketplacePillRadius;
  static const height = AgroAccentColors.marketplaceWidePillHeight;
  /// Svjetljenje karte — tekst lijevo, mapa desno (mockup v3).
  static const _mapStartFraction = 0.54;
  static const _mapFeatherOverlap = 52.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: AgroAccentColors.marketplaceChipGreen,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
              width: 0.8,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalW = constraints.maxWidth;
                final mapStart = totalW * _mapStartFraction;

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: mapStart - _mapFeatherOverlap,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: const _VetMapPreviewCorner(),
                    ),
                    Positioned.fill(
                      right: totalW - mapStart + 20,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pets_outlined,
                              color: Colors.white.withValues(alpha: 0.98),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'vet_finder_open_map'.tr(),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    height: 1.0,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Mapa desno — isti PNG iz odobrene skice mockup_vet_tab_mapa_v3.png.
class _VetMapPreviewCorner extends StatelessWidget {
  const _VetMapPreviewCorner();

  static const _assetPath = 'assets/images/vet_map_preview_corner_v3.png';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        ColoredBox(color: AgroAccentColors.marketplaceChipGreen),
        Positioned(
          left: -24,
          right: 0,
          top: 0,
          bottom: 0,
          child: Transform.scale(
            scale: 1.08,
            alignment: Alignment.centerRight,
            child: Align(
              alignment: Alignment.centerRight,
              child: Image.asset(
                _assetPath,
                height: double.infinity,
                fit: BoxFit.fitHeight,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AgroAccentColors.marketplaceChipGreen,
                AgroAccentColors.marketplaceChipGreen.withValues(alpha: 0.82),
                AgroAccentColors.marketplaceChipGreen.withValues(alpha: 0.38),
                AgroAccentColors.marketplaceChipGreen.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.24, 0.52, 0.82],
            ),
          ),
        ),
      ],
    );
  }
}
