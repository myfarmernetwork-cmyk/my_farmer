import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/follower.dart';

class FollowerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _buyerId => FirebaseAuth.instance.currentUser?.uid;

  Stream<bool> watchIsFollowing(String farmerId) {
    final buyerId = _buyerId;
    if (buyerId == null) return Stream.value(false);

    return _firestore
        .collection('followers')
        .doc(Follower.documentId(buyerId, farmerId))
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<int> watchFollowerCount(String farmerId) {
    return _firestore.collection('users').doc(farmerId).snapshots().map((doc) {
      final count = doc.data()?['followerCount'];
      if (count is num) return count.toInt().clamp(0, 1 << 30);
      return 0;
    });
  }

  Future<void> followFarmer({
    required String farmerId,
    required String farmerName,
  }) async {
    final buyerId = _buyerId;
    if (buyerId == null) {
      throw Exception('Morate biti prijavljeni da biste pratili farmera.');
    }
    if (buyerId == farmerId) {
      throw Exception('Ne možete pratiti vlastiti profil.');
    }

    final followerRef = _firestore
        .collection('followers')
        .doc(Follower.documentId(buyerId, farmerId));
    final farmerRef = _firestore.collection('users').doc(farmerId);

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(followerRef);
      if (existing.exists) return;

      tx.set(
        followerRef,
        Follower(
          buyerId: buyerId,
          farmerId: farmerId,
          farmerName: farmerName,
        ).toMap(),
      );

      final farmerSnap = await tx.get(farmerRef);
      final current =
          (farmerSnap.data()?['followerCount'] as num?)?.toInt() ?? 0;
      tx.set(
        farmerRef,
        {'followerCount': current + 1},
        SetOptions(merge: true),
      );
    });
  }

  Future<void> unfollowFarmer(String farmerId) async {
    final buyerId = _buyerId;
    if (buyerId == null) return;

    final followerRef = _firestore
        .collection('followers')
        .doc(Follower.documentId(buyerId, farmerId));
    final farmerRef = _firestore.collection('users').doc(farmerId);

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(followerRef);
      if (!existing.exists) return;

      tx.delete(followerRef);

      final farmerSnap = await tx.get(farmerRef);
      final current =
          (farmerSnap.data()?['followerCount'] as num?)?.toInt() ?? 0;
      tx.set(
        farmerRef,
        {'followerCount': current > 0 ? current - 1 : 0},
        SetOptions(merge: true),
      );
    });
  }

  Future<void> toggleFollow({
    required String farmerId,
    required String farmerName,
    required bool isCurrentlyFollowing,
  }) async {
    if (isCurrentlyFollowing) {
      await unfollowFarmer(farmerId);
    } else {
      await followFarmer(farmerId: farmerId, farmerName: farmerName);
    }
  }
}

final followerRepositoryProvider = Provider<FollowerRepository>(
  (ref) => FollowerRepository(),
);

final isFollowingProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, farmerId) {
  return ref.watch(followerRepositoryProvider).watchIsFollowing(farmerId);
});

final followerCountProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, farmerId) {
    return ref.watch(followerRepositoryProvider).watchFollowerCount(farmerId);
  },
);
