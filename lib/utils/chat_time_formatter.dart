import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Formatiranje vremena za chat poruke i popis razgovora.
class ChatTimeFormatter {
  ChatTimeFormatter._();

  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return isSameDay(date, now);
  }

  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }

  static String _locale(BuildContext context) => context.locale.toString();

  /// Vrijeme u bubbleu: danas samo sat, inače datum + sat.
  static String bubbleTime(BuildContext context, DateTime date) {
    final locale = _locale(context);
    if (isToday(date)) {
      return DateFormat.Hm(locale).format(date);
    }
    return DateFormat.yMMMd(locale).add_Hm().format(date);
  }

  /// Naslov razdjelnika dana u chatu.
  static String daySeparatorLabel(BuildContext context, DateTime date) {
    if (isToday(date)) {
      return 'chat_time_today'.tr();
    }
    if (isYesterday(date)) {
      return 'chat_time_yesterday'.tr();
    }
    return DateFormat.yMMMd(_locale(context)).format(date);
  }

  /// Kratko vrijeme u popisu chatova (relativno ili datum).
  static String listTime(BuildContext context, DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) {
      final label = 'community_time_just_now'.tr();
      if (label != 'community_time_just_now') return label;
    }
    if (diff.inHours < 1) {
      final label = 'community_time_minutes'.tr(
        namedArgs: {'count': '${diff.inMinutes}'},
      );
      if (label != 'community_time_minutes') return label;
    }
    if (diff.inHours < 24 && isToday(date)) {
      final label = 'community_time_hours'.tr(
        namedArgs: {'count': '${diff.inHours}'},
      );
      if (label != 'community_time_hours') return label;
    }
    if (isYesterday(date)) {
      return 'chat_time_yesterday'.tr();
    }
    if (isToday(date)) {
      return DateFormat.Hm(_locale(context)).format(date);
    }
    return DateFormat.yMMMd(_locale(context)).format(date);
  }
}
