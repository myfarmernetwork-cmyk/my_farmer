import 'package:easy_localization/easy_localization.dart';

/// Canonical weekday codes stored in Firestore (legacy abbreviations normalized on read).
class WeekdayLocalization {
  static const codes = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  static String normalize(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'mon':
      case 'pon':
      case 'monday':
      case 'montag':
        return 'mon';
      case 'tue':
      case 'uto':
      case 'tuesday':
      case 'dienstag':
        return 'tue';
      case 'wed':
      case 'sri':
      case 'sr':
      case 'wednesday':
      case 'mittwoch':
        return 'wed';
      case 'thu':
      case 'čet':
      case 'cet':
      case 'thursday':
      case 'donnerstag':
        return 'thu';
      case 'fri':
      case 'pet':
      case 'friday':
      case 'freitag':
        return 'fri';
      case 'sat':
      case 'sub':
      case 'saturday':
      case 'samstag':
        return 'sat';
      case 'sun':
      case 'ned':
      case 'sunday':
      case 'sonntag':
        return 'sun';
      default:
        return value.length <= 3 ? value : 'mon';
    }
  }

  static List<String> normalizeList(List<String> raw) =>
      raw.map(normalize).toList();

  static String label(String code) => 'weekday_${normalize(code)}'.tr();

  static String formatList(List<String> days) {
    if (days.isEmpty) return 'shop_not_specified'.tr();
    return days.map(label).join(', ');
  }
}
