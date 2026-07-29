import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_post.dart';

class CommunityPostRepository {
  CommunityPostRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collection = 'community_posts';
  static const String legacyCollection = 'posts';
  static const int feedRetentionDays = 365;

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _firestore.collection(collection);

  Timestamp get _feedCutoffTimestamp => Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: feedRetentionDays)),
      );

  bool _isVisibleInFeed(Map<String, dynamic> data) {
    return (data['isReported'] as bool?) != true;
  }

  Stream<List<CommunityPost>> watchFeedPosts() {
    final controller = StreamController<List<CommunityPost>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? primary;
    QuerySnapshot<Map<String, dynamic>>? legacy;
    final cutoff = _feedCutoffTimestamp;

    void emitMerged() {
      final merged = <String, CommunityPost>{};
      for (final snapshot in [primary, legacy]) {
        if (snapshot == null) continue;
        for (final doc in snapshot.docs) {
          if (!_isVisibleInFeed(doc.data())) continue;
          merged[doc.id] = CommunityPost.fromFirestore(doc);
        }
      }
      final posts = merged.values.toList(growable: false);
      posts.sort(_compareNewestFirst);
      controller.add(posts);
    }

    final subscriptions = <StreamSubscription<dynamic>>[
      _postsRef
          .where('timestamp', isGreaterThan: cutoff)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        primary = snapshot;
        emitMerged();
      }),
      _firestore
          .collection(legacyCollection)
          .where('timestamp', isGreaterThan: cutoff)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        legacy = snapshot;
        emitMerged();
      }),
    ];

    controller.onCancel = () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    };

    return controller.stream;
  }

  Stream<List<CommunityPost>> watchReportedPosts() {
    return _postsRef.where('isReported', isEqualTo: true).snapshots().map(
      (snapshot) {
        final posts =
            snapshot.docs.map(CommunityPost.fromFirestore).toList(growable: true);
        posts.sort(_compareNewestFirst);
        return posts;
      },
    );
  }

  Stream<List<CommunityPost>> watchUserGallery(String userId) {
    final controller = StreamController<List<CommunityPost>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? byAuthorId;
    QuerySnapshot<Map<String, dynamic>>? byUserId;
    QuerySnapshot<Map<String, dynamic>>? legacyByUserId;
    QuerySnapshot<Map<String, dynamic>>? legacyByAuthorId;

    void emitMerged() {
      controller.add(
        _mergeUserPosts(
          byAuthorId: byAuthorId,
          byUserId: byUserId,
          legacyByUserId: legacyByUserId,
          legacyByAuthorId: legacyByAuthorId,
        ),
      );
    }

    final subscriptions = <StreamSubscription<dynamic>>[
      _postsRef
          .where('authorId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        byAuthorId = snapshot;
        emitMerged();
      }),
      _postsRef.where('userId', isEqualTo: userId).snapshots().listen((snapshot) {
        byUserId = snapshot;
        emitMerged();
      }),
      _firestore
          .collection(legacyCollection)
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        legacyByUserId = snapshot;
        emitMerged();
      }),
      _firestore
          .collection(legacyCollection)
          .where('authorId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        legacyByAuthorId = snapshot;
        emitMerged();
      }),
    ];

    controller.onCancel = () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    };

    return controller.stream;
  }

  Future<void> publishPost({
    required String imageUrl,
    required String description,
    required String userId,
  }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.data()?['communityPostingBlocked'] == true) {
      throw Exception('community_posting_blocked');
    }

    await _postsRef.add({
      'imageUrl': imageUrl,
      'description': description,
      'userId': userId,
      'authorId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'isReported': false,
      'reportedBy': <String>[],
    });
  }

  Future<void> reportPost({
    required String postId,
    required String reporterId,
  }) async {
    await _postsRef.doc(postId).update({
      'isReported': true,
      'reportedBy': FieldValue.arrayUnion([reporterId]),
      'reportedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> dismissReport(String postId) async {
    await _postsRef.doc(postId).update({
      'isReported': false,
      'reportedBy': <String>[],
      'reportedAt': FieldValue.delete(),
    });
  }

  Future<void> deletePostPermanently({
    required String postId,
    String? authorId,
  }) async {
    await _postsRef.doc(postId).delete();

    if (authorId != null && authorId.isNotEmpty) {
      await blockAuthorFromCommunity(authorId);
    }
  }

  Future<void> blockAuthorFromCommunity(String authorId) async {
    await _firestore.collection('users').doc(authorId).set(
      {
        'communityPostingBlocked': true,
        'communityBlockedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  List<CommunityPost> _mergeUserPosts({
    QuerySnapshot<Map<String, dynamic>>? byAuthorId,
    QuerySnapshot<Map<String, dynamic>>? byUserId,
    QuerySnapshot<Map<String, dynamic>>? legacyByUserId,
    QuerySnapshot<Map<String, dynamic>>? legacyByAuthorId,
  }) {
    final merged = <String, CommunityPost>{};

    for (final snapshot
        in [byAuthorId, byUserId, legacyByUserId, legacyByAuthorId]) {
      if (snapshot == null) continue;
      for (final doc in snapshot.docs) {
        merged[doc.id] = CommunityPost.fromFirestore(doc);
      }
    }

    final posts = merged.values.toList(growable: false);
    posts.sort(_compareNewestFirst);
    return posts;
  }

  static int _compareNewestFirst(CommunityPost a, CommunityPost b) {
    final aMs = a.timestamp?.millisecondsSinceEpoch ?? 0;
    final bMs = b.timestamp?.millisecondsSinceEpoch ?? 0;
    return bMs.compareTo(aMs);
  }
}
