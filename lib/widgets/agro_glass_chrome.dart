import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/agro_accent_colors.dart';

/// Tamno-staklena zelena AppBar — tamnija zelena + blagi blur (ikone ostaju oštre).
class AgroGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AgroGlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.unifiedMarketplaceHeader = false,
  });

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool unifiedMarketplaceHeader;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: unifiedMarketplaceHeader ? false : true,
      titleSpacing: unifiedMarketplaceHeader ? 16 : NavigationToolbar.kMiddleSpacing,
      backgroundColor: unifiedMarketplaceHeader
          ? AgroAccentColors.marketplaceUnifiedGreen
          : AgroAccentColors.headerGreenDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: unifiedMarketplaceHeader
          ? const AgroMarketplaceUnifiedHeaderBackground()
          : const AgroHeaderGlassBackground(),
      foregroundColor: Colors.white,
      title: unifiedMarketplaceHeader
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                child: title,
              ),
            )
          : title,
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Jedna build 70 zelena površina Marktplatza (#388E3C).
class AgroMarketplaceUnifiedHeaderBackground extends StatelessWidget {
  const AgroMarketplaceUnifiedHeaderBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AgroAccentColors.marketplaceUnifiedGreen,
    );
  }
}

/// Zajednička tamno-staklena zelena pozadina (AppBar + filter traka tržišta).
class AgroHeaderGlassBackground extends StatelessWidget {
  const AgroHeaderGlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AgroAccentColors.headerGlassDecoration,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.07),
              Colors.black.withValues(alpha: 0.10),
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.10),
              width: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mjere plutajuće donje navigacije — jedinstveno za padding liste i FAB.
abstract final class AgroBottomNavMetrics {
  static const barHeight = 50.0;
  static const horizontalInset = 16.0;
  static const bottomInset = 8.0;
  static const floatGap = 12.0;
  static const cornerRadius = 22.0;

  static double insetMainTab(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom +
        bottomInset +
        barHeight +
        floatGap;
  }
}

/// Motorola-stil donja navigacija — plutajuća pilula, blur samo na pozadini.
class AgroGlassBottomNav extends StatelessWidget {
  const AgroGlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  static const _iconSize = 22.0;
  static const _labelSize = 10.0;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AgroBottomNavMetrics.horizontalInset,
        0,
        AgroBottomNavMetrics.horizontalInset,
        safeBottom + AgroBottomNavMetrics.bottomInset,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(AgroBottomNavMetrics.cornerRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(AgroBottomNavMetrics.cornerRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AgroAccentColors.navGlassBackground,
                borderRadius:
                    BorderRadius.circular(AgroBottomNavMetrics.cornerRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.68),
                  width: 0.9,
                ),
              ),
              child: SizedBox(
                height: AgroBottomNavMetrics.barHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final selected = index == currentIndex;
                      final color = selected
                          ? AgroAccentColors.marketplaceChipGreen
                          : AgroAccentColors.navInactive;
                      final icon = selected
                          ? (item.activeIcon ?? item.icon)
                          : item.icon;

                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onTap(index),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconTheme(
                                    data: IconThemeData(
                                      color: color,
                                      size: _iconSize,
                                    ),
                                    child: icon,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.label ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: _labelSize,
                                      height: 1.05,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// AppBar ikona s opcionalnim crvenim badgeom — obavijesti, poruke, narudžbe, košarica.
class AgroHeaderIconButton extends StatelessWidget {
  const AgroHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon);
    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
        backgroundColor: Colors.red,
        child: iconWidget,
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: iconWidget,
    );
  }
}

/// Pun zaslon u stilu Trgovine — tamnozeleni AppBar + gradijent tijela.
class MarketplaceScreenScaffold extends StatelessWidget {
  const MarketplaceScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottom,
  });

  final Widget title;
  final Widget body;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgroAccentColors.marketplaceUnifiedGreen,
      appBar: AgroGlassAppBar(
        unifiedMarketplaceHeader: true,
        title: title,
        actions: actions,
        bottom: bottom,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AgroAccentColors.marketplaceUnifiedBackgroundGradient,
        ),
        child: body,
      ),
    );
  }
}

/// TabBar za narudžbe na tamnozelenom AppBar-u.
TabBar marketplaceTabBar({
  TabController? controller,
  required List<Widget> tabs,
}) {
  return TabBar(
    controller: controller,
    indicatorColor: Colors.white,
    indicatorWeight: 3,
    labelColor: Colors.white,
    unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
    tabs: tabs,
  );
}

/// Staklena kartica na tamnozelenoj pozadini (liste, obavijesti, poruke).
class MarketplaceGlassCard extends StatelessWidget {
  const MarketplaceGlassCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    this.padding = const EdgeInsets.all(12),
    this.highlighted = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final bool highlighted;
  final VoidCallback? onTap;

  static BoxDecoration decoration({bool highlighted = false}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AgroAccentColors.marketplaceCornerRadius),
      color: Colors.white.withValues(alpha: highlighted ? 0.20 : 0.13),
      border: Border.all(
        color: highlighted
            ? Colors.orange.shade400
            : Colors.white.withValues(alpha: 0.20),
        width: highlighted ? 1.8 : 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: child,
    );

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: onTap == null
            ? DecoratedBox(
                decoration: decoration(highlighted: highlighted),
                child: content,
              )
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(
                  AgroAccentColors.marketplaceCornerRadius,
                ),
                child: Ink(
                  decoration: decoration(highlighted: highlighted),
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// Bijela kartica profila — build 70 (Trgovina / Zajednica).
BoxDecoration marketplaceProfileCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AgroAccentColors.marketplaceCornerRadius),
    border: Border.all(
      color: AgroAccentColors.marketplaceChipGreen.withValues(alpha: 0.22),
    ),
    boxShadow: AgroAccentColors.marketplaceCardShadow,
  );
}

/// Krem panel na gradijentu — forme, košarica (tamni tekst ostaje čitljiv).
BoxDecoration marketplaceCreamPanelDecoration() {
  return BoxDecoration(
    color: AgroAccentColors.glassTop.withValues(alpha: 0.96),
    borderRadius: BorderRadius.circular(AgroAccentColors.marketplaceCornerRadius),
    border: Border.all(color: AgroAccentColors.borderLight),
    boxShadow: AgroAccentColors.marketplaceCardShadow,
  );
}

/// Bijela polja za unos na unified zelenoj pozadini.
InputDecoration marketplaceFormInputDecoration({
  String? labelText,
  String? hintText,
  String? helperText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? suffixText,
  bool alignLabelWithHint = false,
  EdgeInsetsGeometry? contentPadding,
}) {
  final radius = BorderRadius.circular(AgroAccentColors.marketplaceCornerRadius);
  const chipGreen = AgroAccentColors.marketplaceChipGreen;

  OutlineInputBorder outlineBorder({Color? color, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: color ?? chipGreen.withValues(alpha: 0.22),
        width: width,
      ),
    );
  }

  return InputDecoration(
    hintText: hintText ?? labelText,
    helperText: helperText,
    helperStyle: TextStyle(
      color: Colors.grey.shade600,
      fontSize: 12,
    ),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    suffixText: suffixText,
    suffixStyle: const TextStyle(
      color: chipGreen,
      fontWeight: FontWeight.w600,
    ),
    alignLabelWithHint: alignLabelWithHint,
    filled: true,
    fillColor: Colors.white,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    hintStyle: TextStyle(
      color: Colors.grey.shade500,
      fontSize: 14,
    ),
    border: outlineBorder(),
    enabledBorder: outlineBorder(),
    focusedBorder: outlineBorder(color: chipGreen, width: 1.5),
    contentPadding: contentPadding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

const marketplaceFormFieldTextStyle = TextStyle(
  color: AgroAccentColors.marketplaceChipGreen,
  fontSize: 15,
  fontWeight: FontWeight.w500,
);

/// Naslov iznad polja — bez preklapanja s rubom inputa.
class MarketplaceLabeledField extends StatelessWidget {
  const MarketplaceLabeledField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// FAB za dodavanje — bijeli krug, zeleni plus (chip green).
class MarketplacePrimaryFab extends StatelessWidget {
  const MarketplacePrimaryFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.heroTag,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      elevation: 6,
      highlightElevation: 8,
      backgroundColor: Colors.white,
      foregroundColor: AgroAccentColors.marketplaceChipGreen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AgroAccentColors.marketplaceCornerRadius,
        ),
      ),
      child: Icon(icon, size: 30),
    );
  }
}

/// Krem kartica za profil tab — ista baza kao Trgovina form paneli.
class ProfileCreamCard extends StatelessWidget {
  const ProfileCreamCard({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.padding,
    this.decoration,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? padding;
  final BoxDecoration? decoration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = AgroAccentColors.marketplaceCornerRadius;
    Widget content = Container(
      width: double.infinity,
      decoration: decoration ?? marketplaceProfileCardDecoration(),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }

    return Padding(padding: margin, child: content);
  }
}

/// ListTile unutar krem kartice — standardni profil link.
class ProfileCreamListTile extends StatelessWidget {
  const ProfileCreamListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.margin = EdgeInsets.zero,
    this.decoration,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return ProfileCreamCard(
      margin: margin,
      decoration: decoration,
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing ??
            (onTap != null ? const Icon(Icons.chevron_right) : null),
      ),
    );
  }
}
