import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/agro_accent_colors.dart';

/// Plutajuća paginacija — brojevi i strelice bez trake, brojevi se skrolaju.
class MarketplacePaginationBar extends StatefulWidget {
  const MarketplacePaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
    this.compactNavigation = false,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageSelected;
  final bool compactNavigation;

  @override
  State<MarketplacePaginationBar> createState() =>
      _MarketplacePaginationBarState();
}

class _MarketplacePaginationBarState extends State<MarketplacePaginationBar> {
  static const _pageChipSize = 34.0;
  static const _pageChipSpacing = 6.0;

  final ScrollController _numbersScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPage());
  }

  @override
  void didUpdateWidget(covariant MarketplacePaginationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPage());
    }
  }

  @override
  void dispose() {
    _numbersScrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentPage() {
    if (!_numbersScrollController.hasClients || widget.totalPages <= 1) return;

    const itemStride = _pageChipSize + _pageChipSpacing;
    final target = (widget.currentPage - 1) * itemStride;
    final viewport = _numbersScrollController.position.viewportDimension;
    final maxScroll = _numbersScrollController.position.maxScrollExtent;
    final centered =
        (target - (viewport - _pageChipSize) / 2).clamp(0.0, maxScroll);

    _numbersScrollController.animateTo(
      centered,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Widget _floatingShell({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(
          AgroAccentColors.marketplacePillRadius,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPreviousControl() {
    if (widget.compactNavigation) {
      return _floatingShell(
        child: IconButton(
          onPressed: widget.currentPage > 1
              ? () => widget.onPageSelected(widget.currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left, size: 22),
          color: AgroAccentColors.marketplaceChipGreen,
          disabledColor: Colors.grey.withValues(alpha: 0.45),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: _pageChipSize,
            minHeight: _pageChipSize,
          ),
          tooltip: 'page_previous'.tr(),
        ),
      );
    }

    return TextButton.icon(
      onPressed: widget.currentPage > 1
          ? () => widget.onPageSelected(widget.currentPage - 1)
          : null,
      icon: const Icon(Icons.chevron_left, size: 20),
      label: Text(
        'page_previous'.tr(),
        style: const TextStyle(fontSize: 12),
      ),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildNextControl() {
    if (widget.compactNavigation) {
      return _floatingShell(
        child: IconButton(
          onPressed: widget.currentPage < widget.totalPages
              ? () => widget.onPageSelected(widget.currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right, size: 22),
          color: AgroAccentColors.marketplaceChipGreen,
          disabledColor: Colors.grey.withValues(alpha: 0.45),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: _pageChipSize,
            minHeight: _pageChipSize,
          ),
          tooltip: 'page_next'.tr(),
        ),
      );
    }

    return TextButton.icon(
      onPressed: widget.currentPage < widget.totalPages
          ? () => widget.onPageSelected(widget.currentPage + 1)
          : null,
      icon: const Icon(Icons.chevron_right, size: 20),
      label: Text(
        'page_next'.tr(),
        style: const TextStyle(fontSize: 12),
      ),
      iconAlignment: IconAlignment.end,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildPageChip(int pageNumber) {
    final isActive = pageNumber == widget.currentPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _pageChipSpacing / 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isActive
              ? AgroAccentColors.marketplaceChipGreen
              : Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(
            AgroAccentColors.marketplacePillRadius,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isActive ? null : () => widget.onPageSelected(pageNumber),
            borderRadius: BorderRadius.circular(
              AgroAccentColors.marketplacePillRadius,
            ),
            child: SizedBox(
              width: _pageChipSize,
              height: _pageChipSize,
              child: Center(
                child: Text(
                  '$pageNumber',
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                    color: isActive
                        ? Colors.white
                        : AgroAccentColors.marketplaceChipGreen,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          _buildPreviousControl(),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              controller: _numbersScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(
                  widget.totalPages,
                  (index) => _buildPageChip(index + 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildNextControl(),
        ],
      ),
    );
  }
}
