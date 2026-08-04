import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/forum/repositories/forum_repository.dart';
import 'notification_service.dart';

/// In-app obavijesti za nove teme i odgovore na forumu.
class ForumActivityAlertListener extends StatefulWidget {
  const ForumActivityAlertListener({super.key, required this.child});

  final Widget child;

  @override
  State<ForumActivityAlertListener> createState() =>
      _ForumActivityAlertListenerState();
}

class _ForumActivityAlertListenerState extends State<ForumActivityAlertListener> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _topicsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _commentsSub;

  final Set<String> _seenTopicIds = {};
  final Set<String> _seenCommentIds = {};
  final Map<String, String> _topicAuthors = {};
  final Map<String, String> _topicTitles = {};
  bool _skipInitialTopics = true;
  bool _skipInitialComments = true;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _topicsSub?.cancel();
    _commentsSub?.cancel();

    _topicsSub = FirebaseFirestore.instance
        .collection(ForumRepository.topicsCollection)
        .limit(60)
        .snapshots()
        .listen(_onTopicsUpdate);

    _commentsSub = FirebaseFirestore.instance
        .collection(ForumRepository.commentsCollection)
        .limit(120)
        .snapshots()
        .listen(_onCommentsUpdate);
  }

  void _cacheTopicMeta(String topicId, Map<String, dynamic> data) {
    _topicAuthors[topicId] = data['authorId']?.toString() ?? '';
    _topicTitles[topicId] = data['title']?.toString() ?? '';
  }

  void _onTopicsUpdate(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_skipInitialTopics) {
      for (final doc in snapshot.docs) {
        _seenTopicIds.add(doc.id);
        _cacheTopicMeta(doc.id, doc.data());
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
      _cacheTopicMeta(doc.id, data);

      final authorId = data['authorId']?.toString() ?? '';
      if (authorId.isEmpty || authorId == uid) continue;

      NotificationService().showForumNewTopicAlert(
        topicId: doc.id,
        topicTitle: data['title']?.toString() ?? '',
        authorName: data['authorName']?.toString() ?? '',
      );
    }
  }

  Future<void> _onCommentsUpdate(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_skipInitialComments) {
      for (final doc in snapshot.docs) {
        _seenCommentIds.add(doc.id);
        final topicId = doc.data()['topicId']?.toString() ?? '';
        if (topicId.isNotEmpty) {
          await _ensureTopicCached(topicId);
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
      final commentAuthorId = data['authorId']?.toString() ?? '';
      if (topicId.isEmpty || commentAuthorId.isEmpty) continue;
      if (commentAuthorId == uid) continue;

      await _ensureTopicCached(topicId);
      final topicAuthorId = _topicAuthors[topicId];
      if (topicAuthorId == null || topicAuthorId != uid) continue;

      NotificationService().showForumReplyAlert(
        topicId: topicId,
        topicTitle: _topicTitles[topicId] ?? '',
        authorName: data['authorName']?.toString() ?? '',
        preview: data['text']?.toString() ?? '',
      );
    }
  }

  Future<void> _ensureTopicCached(String topicId) async {
    if (_topicAuthors.containsKey(topicId)) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(ForumRepository.topicsCollection)
          .doc(topicId)
          .get();
      if (!doc.exists) return;
      _cacheTopicMeta(topicId, doc.data() ?? {});
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
