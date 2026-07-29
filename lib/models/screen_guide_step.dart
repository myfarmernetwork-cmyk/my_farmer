import 'package:flutter/material.dart';

class ScreenGuideStep {
  const ScreenGuideStep({
    this.targetKey,
    required this.titleKey,
    required this.bodyKey,
    this.highlightPadding = const EdgeInsets.all(8),
    this.highlightLabelKey,
  });

  final GlobalKey? targetKey;
  final String titleKey;
  final String bodyKey;
  final EdgeInsets highlightPadding;

  /// Ako je postavljeno, iznad overlay-a se crta svijetla replika gumba (FAB).
  final String? highlightLabelKey;
}
