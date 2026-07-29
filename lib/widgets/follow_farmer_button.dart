import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/follower_repository.dart';

class FollowFarmerButton extends ConsumerWidget {
  final String farmerId;
  final String farmerName;

  const FollowFarmerButton({
    super.key,
    required this.farmerId,
    required this.farmerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followAsync = ref.watch(isFollowingProvider(farmerId));
    final isFollowing = followAsync.value ?? false;
    final isLoading = followAsync.isLoading;

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
                            ? 'Više ne pratite $farmerName'
                            : 'Pratite $farmerName — obavijestit ćemo vas o novim proizvodima',
                      ),
                      backgroundColor:
                          isFollowing ? Colors.grey[700] : Colors.green,
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
        ),
        label: Text(isFollowing ? 'PRATIŠ' : 'ZAPRATI'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.green[700] : Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
