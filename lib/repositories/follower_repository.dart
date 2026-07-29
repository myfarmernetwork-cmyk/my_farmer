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

    await _firestore
        .collection('followers')
        .doc(Follower.documentId(buyerId, farmerId))
        .set(
      Follower(
        buyerId: buyerId,
        farmerId: farmerId,
        farmerName: farmerName,
      ).toMap(),
    );
  }

  Future<void> unfollowFarmer(String farmerId) async {
    final buyerId = _buyerId;
    if (buyerId == null) return;

    await _firestore
        .collection('followers')
        .doc(Follower.documentId(buyerId, farmerId))
        .delete();
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
