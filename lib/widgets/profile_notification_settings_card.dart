import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/notification_prefs.dart';
import '../../services/notification_service.dart';
import '../../theme/agro_accent_colors.dart';
import 'agro_glass_chrome.dart';

/// Prekidač: bez push obavijesti dok app nije otvoren (meteo iznimka).
class ProfileNotificationSettingsCard extends ConsumerStatefulWidget {
  const ProfileNotificationSettingsCard({super.key});

  @override
  ConsumerState<ProfileNotificationSettingsCard> createState() =>
      _ProfileNotificationSettingsCardState();
}

class _ProfileNotificationSettingsCardState
    extends ConsumerState<ProfileNotificationSettingsCard> {
  bool? _quietWhenBackground;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final quiet = doc.data()?['quietWhenBackground'] as bool? ?? false;
      await NotificationPrefs.setQuietWhenBackground(quiet);
      await NotificationService().syncQuietWhenBackground(quiet);
      if (mounted) setState(() => _quietWhenBackground = quiet);
    } catch (_) {
      final quiet = await NotificationPrefs.quietWhenBackground();
      if (mounted) setState(() => _quietWhenBackground = quiet);
    }
  }

  Future<void> _onChanged(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _saving) return;

    setState(() {
      _quietWhenBackground = value;
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'quietWhenBackground': value},
        SetOptions(merge: true),
      );
      await NotificationPrefs.setQuietWhenBackground(value);
      await NotificationService().syncQuietWhenBackground(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': ''})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiet = _quietWhenBackground;

    return ProfileCreamCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.notifications_outlined,
                      color: AgroAccentColors.marketplaceChipGreen, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'profile_notifications_title'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AgroAccentColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text('profile_quiet_when_background_title'.tr()),
              subtitle: Text(
                'profile_quiet_when_background_subtitle'.tr(),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              value: quiet ?? false,
              activeTrackColor: AgroAccentColors.marketplaceChipGreen.withValues(alpha: 0.45),
              activeThumbColor: AgroAccentColors.marketplaceChipGreen,
              onChanged: quiet == null || _saving ? null : _onChanged,
            ),
          ],
        ),
    );
  }
}
