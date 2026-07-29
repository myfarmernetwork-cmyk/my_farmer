import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'farmer_help_widgets.dart';

class PendingVerificationBanner extends ConsumerWidget {
  const PendingVerificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    // StreamBuilder ne rebuilda inner builder kad se promijeni locale — key ga prisiljava.
    final localeKey = context.locale.toString();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey('pending_verify_banner_$localeKey'),
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data();
        if (data == null) return const SizedBox.shrink();

        final role = data['role'] as String? ?? '';
        if (!AppUser.roleNeedsVerification(role)) {
          return const SizedBox.shrink();
        }

        final premiumStatus = data['premiumApprovalStatus']
                ?.toString()
                .trim()
                .toUpperCase() ??
            '';

        if (premiumStatus != 'PENDING') {
          return const SizedBox.shrink();
        }

        final bannerText = farmerGuideTr(context, 'premium_pending_banner');

        return Material(
          color: Colors.orange.shade100,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.hourglass_top, color: Colors.orange.shade900),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bannerText,
                    key: ValueKey('premium_pending_text_$localeKey'),
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
