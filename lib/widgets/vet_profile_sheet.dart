import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/chat/chat_screen.dart';
import '../services/vet_navigation_service.dart';
import '../services/vet_proximity_radar_service.dart';

Future<void> showVetProfileSheet({
  required BuildContext context,
  required WidgetRef ref,
  required VetProfile vet,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green[50],
                  child: Icon(Icons.medical_services, color: Colors.green[800]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vet.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (vet.address.isNotEmpty)
                        Text(
                          vet.address,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      if (vet.distanceKm != null)
                        Text(
                          '${vet.distanceKm!.toStringAsFixed(1)} km',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                if (vet.isPremium)
                  Icon(Icons.verified, color: Colors.green[700]),
              ],
            ),
            const SizedBox(height: 20),
            if (vet.hasLocation)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final ok = await openVetDirections(vet);
                    if (!ok && ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('vet_navigate_failed'.tr())),
                      );
                    }
                  },
                  icon: const Icon(Icons.directions),
                  label: Text('vet_navigate'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            if (!vet.hasLocation)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'vet_map_no_location'.tr(),
                  style: TextStyle(color: Colors.orange[800]),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (vet.phone.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final normalized =
                            vet.phone.replaceAll(RegExp(r'[^\d+]'), '');
                        final uri = Uri.parse('tel:$normalized');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      icon: const Icon(Icons.phone_outlined),
                      label: Text('first_aid_call'.tr()),
                    ),
                  ),
                if (vet.phone.isNotEmpty) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            receiverId: vet.uid,
                            receiverName: vet.name,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text('first_aid_chat'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
