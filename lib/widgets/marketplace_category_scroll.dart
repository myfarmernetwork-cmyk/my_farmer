import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/product_categories.dart';
import 'marketplace_category_scroll_items.dart';
import 'marketplace_category_scroll_tile.dart';

/// Horizontalna traka kategorija tržišta — fluidan scroll, haptic, simetrične kartice.
class MarketplaceCategoryScrollBar extends StatefulWidget {
  const MarketplaceCategoryScrollBar({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.items = MarketplaceCategoryScrollCatalog.items,
  });

  final List<MarketplaceCategoryScrollItem> items;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  static const listHeight = MarketplaceCategoryScrollTile.tileHeight;

  @override
  State<MarketplaceCategoryScrollBar> createState() =>
      _MarketplaceCategoryScrollBarState();
}

class _MarketplaceCategoryScrollBarState
    extends State<MarketplaceCategoryScrollBar> {
  static const _itemGap = 8.0;

  void _onTileTap(String code) {
    HapticFeedback.lightImpact();
    if (code == widget.selectedCategory) return;
    widget.onCategorySelected(code);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MarketplaceCategoryScrollBar.listHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < widget.items.length - 1 ? _itemGap : 0,
            ),
            child: MarketplaceCategoryScrollTile(
              icon: item.icon,
              label: ProductCategories.label(item.code),
              isSelected: widget.selectedCategory == item.code,
              onTap: () => _onTileTap(item.code),
            ),
          );
        },
      ),
    );
  }
}
