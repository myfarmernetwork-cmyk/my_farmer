import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/follower_repository.dart';

/// Prikazuje samo ukupan broj pratitelja — bez popisa tko prati.
class FarmerFollowerCountBadge extends ConsumerWidget {
  const FarmerFollowerCountBadge({
    super.key,
    required this.farmerId,
  });

  final String farmerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(followerCountProvider(farmerId));
    final count = countAsync.value ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_active_outlined,
              size: 18, color: Colors.green.shade800),
          const SizedBox(width: 8),
          Text(
            'profile_followers_count'.tr(namedArgs: {'count': '$count'}),
            style: TextStyle(
              color: Colors.green.shade900,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
