import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

const _onlineThreshold = Duration(minutes: 2);

bool isUserCurrentlyInApp(Map<String, dynamic> data) {
  final lastActiveAt = data['lastActiveAt'];
  if (lastActiveAt is! Timestamp) return false;

  final elapsed = DateTime.now().difference(lastActiveAt.toDate());
  if (elapsed > _onlineThreshold) return false;

  return data['isOnline'] == true || elapsed < const Duration(minutes: 1);
}

String formatAdminLastActive(Map<String, dynamic> data) {
  final lastActiveAt = data['lastActiveAt'];
  if (lastActiveAt is! Timestamp) {
    return 'admin_presence_never'.tr();
  }

  final dt = lastActiveAt.toDate();
  final elapsed = DateTime.now().difference(dt);

  if (elapsed.inSeconds < 45) {
    return 'admin_presence_just_now'.tr();
  }
  if (elapsed.inMinutes < 60) {
    return 'admin_presence_minutes_ago'.tr(
      namedArgs: {'min': '${elapsed.inMinutes}'},
    );
  }
  if (elapsed.inHours < 24) {
    return 'admin_presence_hours_ago'.tr(
      namedArgs: {'hours': '${elapsed.inHours}'},
    );
  }
  if (elapsed.inDays < 7) {
    return 'admin_presence_days_ago'.tr(
      namedArgs: {'days': '${elapsed.inDays}'},
    );
  }

  return DateFormat('dd.MM.yyyy HH:mm').format(dt);
}

Widget adminPresenceIndicator({
  required Map<String, dynamic> data,
  double size = 10,
}) {
  final online = isUserCurrentlyInApp(data);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: online ? Colors.green : Colors.grey.shade400,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
  );
}

String adminPresenceSummary(Map<String, dynamic> data) {
  if (isUserCurrentlyInApp(data)) {
    return 'admin_presence_online'.tr();
  }
  return 'admin_presence_last_seen'.tr(
    namedArgs: {'time': formatAdminLastActive(data)},
  );
}
