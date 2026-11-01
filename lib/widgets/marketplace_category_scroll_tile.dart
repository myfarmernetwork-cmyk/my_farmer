import 'package:flutter/material.dart';

import '../theme/agro_accent_colors.dart';
import 'marketplace_category_scroll_icon.dart';
import 'marketplace_category_scroll_items.dart';

/// Premium kartica kategorije — simetrična visina, širina po sadržaju.
class MarketplaceCategoryScrollTile extends StatelessWidget {
  const MarketplaceCategoryScrollTile({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final MarketplaceCategoryScrollIconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  static const tileHeight = 110.0;
  static const cornerRadius = 20.0;
  static const borderWidth = 1.5;
  static const iconSize = 32.0;
  static const labelFontSize = 12.5;
  static const labelMaxWidth = 148.0;

  static const _animationDuration = Duration(milliseconds: 220);
  static const _animationCurve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    final chipGreen = AgroAccentColors.marketplaceChipGreen;
    final foreground = isSelected ? chipGreen : Colors.white;
    final background = isSelected ? Colors.white : chipGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cornerRadius),
        splashColor: isSelected
            ? chipGreen.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.12),
        highlightColor: isSelected
            ? chipGreen.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: _animationDuration,
          curve: _animationCurve,
          height: tileHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cornerRadius),
            color: background,
            border: Border.all(
              color: isSelected
                  ? chipGreen.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.20),
              width: borderWidth,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              MarketplaceCategoryScrollIcon(
                icon: icon,
                color: foreground,
                size: iconSize,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: labelMaxWidth),
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: labelFontSize,
                    height: 1.2,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
