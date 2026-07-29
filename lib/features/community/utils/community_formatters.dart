import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/app_user.dart';

class CommunityFormatters {
  static String _formatAbsoluteDate(BuildContext context, DateTime date) {
    final locale = context.locale.toString();
    return DateFormat.yMMMd(locale).add_Hm().format(date);
  }

  static String _trOrAbsoluteDate(
    BuildContext context,
    String key,
    DateTime date, {
    Map<String, String>? namedArgs,
  }) {
    final translated = namedArgs == null
        ? key.tr()
        : key.tr(namedArgs: namedArgs);
    if (translated != key) return translated;
    return _formatAbsoluteDate(context, date);
  }
  static String roleLabel(String? role) {
    final canonical = AppUser.normalizeRoleAlias(role);
    switch (canonical) {
      case 'hobby_farmer':
        return 'role_hobby_farmer'.tr();
      case 'professional_farmer':
      case 'farmer':
        return 'role_professional_farmer'.tr();
      case 'veterinarian':
        return 'role_veterinarian'.tr();
      case 'pharmacy':
        return 'role_pharmacy'.tr();
      case 'firma':
      case 'company':
        return 'role_company'.tr();
      case 'admin':
        final adminLabel = 'role_admin'.tr();
        return adminLabel != 'role_admin' ? adminLabel : 'Admin';
      case 'services':
        return 'services'.tr();
      case 'buyer':
        return 'role_buyer'.tr();
      default:
        final key = 'role_$canonical';
        final translated = key.tr();
        return translated != key ? translated : 'role_buyer'.tr();
    }
  }

  static Color roleColor(String? role) {
    final normalized = AppUser.normalizeRoleAlias(role);
    switch (normalized) {
      case 'hobby_farmer':
        return Colors.lightGreen.shade800;
      case 'professional_farmer':
      case 'farmer':
        return Colors.orange.shade800;
      case 'veterinarian':
      case 'veterinar':
        return Colors.teal.shade800;
      case 'pharmacy':
      case 'firma':
      case 'company':
        return Colors.deepPurple.shade800;
      case 'admin':
        return Colors.orange.shade900;
      case 'services':
        return Colors.blue.shade800;
      default:
        return Colors.green.shade800;
    }
  }

  static String relativeTime(BuildContext context, Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) {
      return _trOrAbsoluteDate(context, 'community_time_just_now', date);
    }
    if (diff.inHours < 1) {
      return _trOrAbsoluteDate(
        context,
        'community_time_minutes',
        date,
        namedArgs: {'count': '${diff.inMinutes}'},
      );
    }
    if (diff.inHours < 24) {
      return _trOrAbsoluteDate(
        context,
        'community_time_hours',
        date,
        namedArgs: {'count': '${diff.inHours}'},
      );
    }

    return _formatAbsoluteDate(context, date);
  }
}
