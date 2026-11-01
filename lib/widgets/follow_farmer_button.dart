import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/follower_repository.dart';
import '../theme/agro_accent_colors.dart';

class FollowFarmerButton extends ConsumerWidget {
  const FollowFarmerButton({
    super.key,
    required this.farmerId,
    required this.farmerName,
    this.marketplaceStyle = false,
  });

  final String farmerId;
  final String farmerName;
  final bool marketplaceStyle;

  static const _priceYellow = Color(0xFFFFEB3B);
  static const _buttonHeight = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followAsync = ref.watch(isFollowingProvider(farmerId));
    final isFollowing = followAsync.value ?? false;
    final isLoading = followAsync.isLoading;
    final chipGreen = AgroAccentColors.marketplaceChipGreen;

    return Expanded(
      child: ElevatedButton.icon(
        onPressed: isLoading
            ? null
            : () async {
                try {
                  await ref.read(followerRepositoryProvider).toggleFollow(
                        farmerId: farmerId,
                        farmerName: farmerName,
                        isCurrentlyFollowing: isFollowing,
                      );

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFollowing
                            ? 'follow_farmer_stopped'.tr(
                                namedArgs: {'name': farmerName},
                              )
                            : 'follow_farmer_started'.tr(
                                namedArgs: {'name': farmerName},
                              ),
                      ),
                      backgroundColor:
                          isFollowing ? Colors.grey[700] : chipGreen,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
        icon: Icon(
          isFollowing ? Icons.notifications_active : Icons.notifications_none,
          size: marketplaceStyle ? 18 : 24,
        ),
        label: Text(
          isFollowing
              ? 'follow_farmer_active'.tr()
              : 'follow_farmer_action'.tr(),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
        style: marketplaceStyle
            ? ElevatedButton.styleFrom(
                backgroundColor:
                    isFollowing ? Colors.white : chipGreen,
                foregroundColor:
                    isFollowing ? chipGreen : _priceYellow,
                disabledBackgroundColor: chipGreen.withValues(alpha: 0.45),
                disabledForegroundColor: _priceYellow.withValues(alpha: 0.45),
                minimumSize: const Size(0, _buttonHeight),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                shape: const StadiumBorder(),
                elevation: 2,
              )
            : ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.green[700] : Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
      ),
    );
  }
}
