import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Locales where English "My …" must not be prepended (title keys hold the full phrase).
bool localeUsesFullPossessiveTitles(Locale locale) {
  switch (locale.languageCode) {
    case 'zh':
    case 'uk':
    case 'sr':
    case 'bs':
    case 'hr':
      return true;
    default:
      return false;
  }
}

/// Full possessive title from [titleKey] — no English "My " prefix (e.g. "Moja košarica", "Moja korpa").
String localizedMyPrefixedTitle(BuildContext context, String titleKey) {
  final translated = titleKey.tr();
  if (localeUsesFullPossessiveTitles(context.locale)) {
    return translated;
  }
  return 'My $translated';
}
