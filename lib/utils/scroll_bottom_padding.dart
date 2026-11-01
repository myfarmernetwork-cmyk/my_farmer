import 'package:flutter/material.dart';

import '../widgets/agro_glass_chrome.dart';

/// Donji razmak za skrolabilan sadržaj — izbjegava preklapanje s donjom
/// navigacijom aplikacije ili sistemskom gesture trakom.
abstract final class ScrollBottomPadding {
  static double inset(BuildContext context, {double extra = 16}) {
    return MediaQuery.paddingOf(context).bottom + extra;
  }

  /// Tab unutar [MainNavigationScreen] — razmak iznad plutajuće donje navigacije.
  static double insetMainTab(BuildContext context) {
    return AgroBottomNavMetrics.insetMainTab(context);
  }

  /// Push rute (pun zaslon bez donje app navigacije).
  static double insetFullScreen(BuildContext context) {
    return inset(context, extra: 16);
  }

  static EdgeInsets list(
    BuildContext context, {
    EdgeInsets base = const EdgeInsets.all(12),
    bool mainTab = false,
  }) {
    final bottom = base.bottom +
        (mainTab ? insetMainTab(context) : insetFullScreen(context));
    return base.copyWith(bottom: bottom);
  }

  /// FAB iznad plutajuće donje navigacije (MainNavigationScreen + extendBody).
  static const fabLocationMainTab = MainTabFloatingActionButtonLocation();

  /// FAB iznad navigacije i fiksne paginacije (legacy).
  static const fabLocationMainTabAbovePagination =
      MainTabFloatingActionButtonLocation(extraAboveNavBar: 52);

  /// Galerija / Zajednica — FAB iznad plutajuće navigacije.
  static const fabLocationMainTabRaised =
      MainTabFloatingActionButtonLocation(extraAboveNavBar: 56);

  /// Forum — extended FAB „Nova tema” (Moto 50 Pro i slični zasloni).
  static const fabLocationForum =
      MainTabFloatingActionButtonLocation(extraAboveNavBar: 56);

  /// Galerija — isti offset kao [fabLocationMainTabRaised].
  static const fabLocationGallery = fabLocationMainTabRaised;

  /// Zajednica — FAB iznad paginacije (traka stranica + razmak).
  static const fabLocationCommunity =
      MainTabFloatingActionButtonLocation(extraAboveNavBar: 108);
}

/// Pozicija FAB-a iznad [AgroGlassBottomNav] pilule.
class MainTabFloatingActionButtonLocation extends FloatingActionButtonLocation {
  const MainTabFloatingActionButtonLocation({
    this.extraAboveNavBar = 16,
  });

  final double extraAboveNavBar;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fabSize = scaffoldGeometry.floatingActionButtonSize;
    final scaffoldSize = scaffoldGeometry.scaffoldSize;
    final safeBottom = scaffoldGeometry.minViewPadding.bottom;
    final bottomClearance = safeBottom +
        AgroBottomNavMetrics.bottomInset +
        AgroBottomNavMetrics.barHeight +
        AgroBottomNavMetrics.floatGap +
        extraAboveNavBar;

    return Offset(
      scaffoldSize.width - fabSize.width - 16,
      scaffoldSize.height - fabSize.height - bottomClearance,
    );
  }
}