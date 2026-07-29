import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../widgets/farmer_help_widgets.dart';

/// NIRS/NDVI tekst — .tr() pa fallback iz [kFarmerGuideFallbacks].
String nirsLabel(BuildContext context, String key) {
  return farmerGuideTr(context, key);
}

String nirsLabelArgs(
  BuildContext context,
  String key,
  Map<String, String> namedArgs,
) {
  final translated = key.tr(namedArgs: namedArgs);
  if (translated != key) return translated;

  var fallback = farmerGuideTr(context, key);
  for (final entry in namedArgs.entries) {
    fallback = fallback.replaceAll('{${entry.key}}', entry.value);
  }
  return fallback;
}
