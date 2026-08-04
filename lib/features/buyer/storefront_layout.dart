import 'package:flutter/material.dart';

/// Shared responsive layout helpers for the public seller storefront.
class StorefrontLayout {
  StorefrontLayout._();

  static const double maxContentWidth = 720;

  static double horizontalPadding(double width) {
    if (width >= 600) return 24;
    if (width >= 360) return 16;
    return 12;
  }

  static double productImageSize(double width) {
    return (width * 0.19).clamp(64.0, 80.0);
  }

  static double tabFontSize(double width) {
    if (width < 340) return 11;
    if (width < 380) return 12;
    return 13;
  }

  static int galleryCrossAxisCount(double width) {
    if (width >= 720) return 4;
    if (width >= 520) return 3;
    return 2;
  }

  static BoxConstraints contentConstraints(BoxConstraints parent) {
    final width = parent.maxWidth.isFinite
        ? parent.maxWidth.clamp(0.0, maxContentWidth)
        : maxContentWidth;
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: parent.maxHeight.isFinite ? parent.maxHeight : 0,
      maxHeight: parent.maxHeight.isFinite ? parent.maxHeight : double.infinity,
    );
  }

  static Widget constrainContent({
    required BoxConstraints constraints,
    required Widget child,
  }) {
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth.clamp(0.0, maxContentWidth)
        : maxContentWidth;

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: child,
      ),
    );
  }
}
