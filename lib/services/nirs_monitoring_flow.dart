import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../features/land/repositories/land_parcel_repository.dart';
import '../models/nirs_scan_result.dart';
import '../models/premium_access.dart';
import '../providers/subscription_provider.dart';
import '../services/nirs/nirs_monitoring_service.dart';
import '../services/nirs_limit_service.dart';
import '../widgets/farmer_help_widgets.dart';
import '../widgets/premium_gate.dart';

class NirsMonitoringFlow {
  NirsMonitoringFlow._();

  static Future<NirsScanResult?> confirmAndRun({
    required BuildContext context,
    required WidgetRef ref,
    required List<LatLng> points,
    String? parcelId,
    LandParcelRepository? repository,
  }) async {
    if (points.length < 3) return null;

    final access = ref.read(premiumAccessProvider);
    if (!access.canUseNirsMonitoring) {
      await showPremiumRequiredDialog(context, ref);
      return null;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    final quota = await ref.read(nirsLimitServiceProvider).getQuotaStatus(
          userId: userId,
          access: access,
        );
    if (!quota.canLoad) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('land_nirs_limit_monthly'.tr()),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
      return null;
    }

    if (!context.mounted) return null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('land_nirs_load_title'.tr()),
        content: Text('land_nirs_load_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return null;

    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('land_nirs_loading'.tr()),
                ],
              ),
            ),
          ),
        ),
      );
    }

    NirsScanResult result;
    try {
      result = await ref.read(nirsMonitoringServiceProvider).analyzeParcel(points);
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': '$error'})),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    await ref.read(nirsLimitServiceProvider).recordNirsLoad(userId: userId);

    if (parcelId != null && parcelId.isNotEmpty) {
      result = await (repository ?? LandParcelRepository()).recordNirsScan(
        parcelId: parcelId,
        result: result,
      );
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    return result;
  }

  static Future<void> showPremiumRequiredDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _showPremiumDialog(context, ref);
  }

  static Future<void> _showPremiumDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final isPremium = ref.read(isPremiumProvider).value ?? false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Text('🍃'),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'land_nirs_premium_title'.tr(),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            Icon(Icons.workspace_premium, color: Colors.amber[700]),
          ],
        ),
        content: Text(
          'land_nirs_premium_body'.tr(),
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: Colors.grey.shade800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ok'.tr()),
          ),
          if (!isPremium)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                PremiumGate.run(
                  context,
                  ref,
                  feature: PremiumFeature.landMeasurement,
                  onUnlocked: () {},
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
              ),
              child: Text(farmerGuideTr(context, 'land_premium_activate')),
            ),
        ],
      ),
    );
  }
}
