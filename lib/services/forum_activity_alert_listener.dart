import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/forum/models/forum_category.dart';
import '../features/forum/repositories/forum_repository.dart';
import '../providers/forum_activity_provider.dart';
import 'forum_seen_prefs.dart';

/// Prati forum aktivnost samo u app-u — oznake po kategorijama, bez push-a.
class ForumActivityAlertListener extends ConsumerStatefulWidget {
  const ForumActivityAlertListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ForumActivityAlertListener> createState() =>
      _ForumActivityAlertListenerState();
}

class _ForumActivityAlertListenerState
    extends ConsumerState<ForumActivityAlertListener> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _topicsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _commentsSub;

  final Set<String> _seenTopicIds = {};
  final Set<String> _seenCommentIds = {};
  final Map<String, ForumCategory> _topicCategories = {};
  bool _skipInitialTopics = true;
  bool _skipInitialComments = true;
  Map<ForumCategory, DateTime> _seenAt = {};

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _seenAt = await ForumSeenPrefs.allSeenAt(uid);
    await _scanExistingActivity(uid);
    if (mounted) _subscribe(uid);
  }

  Future<void> _scanExistingActivity(String uid) async {
    try {
      final topicsSnap = await FirebaseFirestore.instance
          .collection(ForumRepository.topicsCollection)
          .limit(100)
          .get();

      for (final doc in topicsSnap.docs) {
        final data = doc.data();
        final category =
            ForumCategoryX.fromFirestore(data['category']?.toString());
        _topicCategories[doc.id] = category;

        final authorId = data['authorId']?.toString() ?? '';
        if (authorId.isEmpty || authorId == uid) continue;

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) continue;

        final seen = _seenAt[category];
        if (seen == null || createdAt.isAfter(seen)) {
          ref.read(forumActivityProvider.notifier).markCategoryActive(category);
        }
      }

      final commentsSnap = await FirebaseFirestore.instance
          .collection(ForumRepository.commentsCollection)
          .limit(120)
          .get();

      for (final doc in commentsSnap.docs) {
        final data = doc.data();
        final topicId = data['topicId']?.toString() ?? '';
        final authorId = data['authorId']?.toString() ?? '';
        if (topicId.isEmpty || authorId.isEmpty || authorId == uid) continue;

        final category = await _categoryForTopic(topicId);
        if (category == null) continue;

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) continue;

        final seen = _seenAt[category];
        if (seen == null || createdAt.isAfter(seen)) {
          ref.read(forumActivityProvider.notifier).markCategoryActive(category);
        }
      }
    } catch (_) {}
  }

  void _subscribe(String uid) {
    _topicsSub?.cancel();
    _commentsSub?.cancel();

    _topicsSub = FirebaseFirestore.instance
        .collection(ForumRepository.topicsCollection)
        .limit(60)
        .snapshots()
        .listen((snapshot) => _onTopicsUpdate(snapshot, uid));

    _commentsSub = FirebaseFirestore.instance
        .collection(ForumRepository.commentsCollection)
        .limit(120)
        .snapshots()
        .listen((snapshot) => _onCommentsUpdate(snapshot, uid));
  }

  void _cacheTopicCategory(String topicId, Map<String, dynamic> data) {
    _topicCategories[topicId] =
        ForumCategoryX.fromFirestore(data['category']?.toString());
  }

  void _onTopicsUpdate(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String uid,
  ) {
    if (_skipInitialTopics) {
      for (final doc in snapshot.docs) {
        _seenTopicIds.add(doc.id);
        _cacheTopicCategory(doc.id, doc.data());
      }
      _skipInitialTopics = false;
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final doc = change.doc;
      if (_seenTopicIds.contains(doc.id)) continue;
      _seenTopicIds.add(doc.id);

      final data = doc.data();
      if (data == null) continue;
      _cacheTopicCategory(doc.id, data);

      final authorId = data['authorId']?.toString() ?? '';
      if (authorId.isEmpty || authorId == uid) continue;

      ref
          .read(forumActivityProvider.notifier)
          .markCategoryActive(_topicCategories[doc.id]!);
    }
  }

  Future<void> _onCommentsUpdate(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String uid,
  ) async {
    if (_skipInitialComments) {
      for (final doc in snapshot.docs) {
        _seenCommentIds.add(doc.id);
        final topicId = doc.data()['topicId']?.toString() ?? '';
        if (topicId.isNotEmpty) {
          await _ensureTopicCategoryCached(topicId);
        }
      }
      _skipInitialComments = false;
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final doc = change.doc;
      if (_seenCommentIds.contains(doc.id)) continue;
      _seenCommentIds.add(doc.id);

      final data = doc.data();
      if (data == null) continue;

      final topicId = data['topicId']?.toString() ?? '';
      final authorId = data['authorId']?.toString() ?? '';
      if (topicId.isEmpty || authorId.isEmpty || authorId == uid) continue;

      final category = await _categoryForTopic(topicId);
      if (category == null) continue;

      ref.read(forumActivityProvider.notifier).markCategoryActive(category);
    }
  }

  Future<ForumCategory?> _categoryForTopic(String topicId) async {
    if (_topicCategories.containsKey(topicId)) {
      return _topicCategories[topicId];
    }
    await _ensureTopicCategoryCached(topicId);
    return _topicCategories[topicId];
  }

  Future<void> _ensureTopicCategoryCached(String topicId) async {
    if (_topicCategories.containsKey(topicId)) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(ForumRepository.topicsCollection)
          .doc(topicId)
          .get();
      if (!doc.exists) return;
      _cacheTopicCategory(topicId, doc.data() ?? {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _topicsSub?.cancel();
    _commentsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
