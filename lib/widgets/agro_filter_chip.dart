import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/agro_accent_colors.dart';

/// Stil filter chipa u tamno-zelenoj traci tržišta.
enum AgroFilterChipVariant {
  /// Prozirno staklo na tamnoj pozadini.
  inactive,

  /// Bijeli stakleni pill (kategorija / radius).
  whiteSelected,

  /// Medno staklo — tip proizvodnje „Alle“.
  honeySelected,
}

/// Diskretni rub bez vidljive crte — sjene + highlight (OneSoil stil).
BoxDecoration agroFilterChipDecoration(AgroFilterChipVariant variant) {
  const radius = 20.0;

  switch (variant) {
    case AgroFilterChipVariant.inactive:
      return BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: AgroAccentColors.marketplaceChipGreen,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 0.8,
        ),
      );

    case AgroFilterChipVariant.whiteSelected:
      return BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.white.withValues(alpha: 0.96),
        border: Border.all(
          color: AgroAccentColors.marketplaceChipGreen.withValues(alpha: 0.35),
          width: 1,
        ),
      );

    case AgroFilterChipVariant.honeySelected:
      return BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AgroAccentColors.honeyGlassTop.withValues(alpha: 0.94),
            AgroAccentColors.honeyGlassBottom.withValues(alpha: 0.98),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: AgroAccentColors.honeyGlassHighlight.withValues(alpha: 0.25),
            blurRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      );
  }
}

/// Filter zona — staklo (blur 20px + bijelo 15%) samo oko chipova.
class AgroFilterZone extends StatelessWidget {
  const AgroFilterZone({
    super.key,
    required this.child,
  });

  final Widget child;

  static const _radius = AgroAccentColors.marketplaceCornerRadius;
  static const _blurSigma = 20.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AgroAccentColors.filterZoneGlassFill,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

@Deprecated('Use AgroFilterZone widget instead')
BoxDecoration get agroFilterZoneDecoration => BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: AgroAccentColors.filterZoneGlassFill,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.18),
        width: 0.8,
      ),
    );

class AgroFilterChip extends StatelessWidget {
  const AgroFilterChip({
    super.key,
    required this.label,
    required this.variant,
    required this.onTap,
    this.textStyle,
    this.margin = const EdgeInsets.only(right: 8),
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  final String label;
  final AgroFilterChipVariant variant;
  final VoidCallback onTap;
  final TextStyle? textStyle;
  final EdgeInsets margin;
  final EdgeInsets padding;

  TextStyle _defaultTextStyle() {
    switch (variant) {
      case AgroFilterChipVariant.inactive:
        return TextStyle(
          color: Colors.white.withValues(alpha: 0.94),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        );
      case AgroFilterChipVariant.whiteSelected:
        return const TextStyle(
          color: AgroAccentColors.marketplaceChipGreen,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        );
      case AgroFilterChipVariant.honeySelected:
        return const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: agroFilterChipDecoration(variant),
        child: Text(
          label,
          style: textStyle ?? _defaultTextStyle(),
        ),
      ),
    );
  }
}
