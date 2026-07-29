import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/forum_category.dart';
import '../models/forum_comment.dart';
import '../models/forum_topic.dart';

class ForumRepository {
  ForumRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String topicsCollection = 'forum_topics';
  static const String commentsCollection = 'forum_comments';

  CollectionReference<Map<String, dynamic>> get _topicsRef =>
      _firestore.collection(topicsCollection);

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      _firestore.collection(commentsCollection);

  /// Jednostavan jednokratni dohvat — bez orderBy (nema čekanja na indeks).
  Future<List<ForumTopic>> fetchTopics(ForumCategory category) async {
    try {
      final snapshot = await _topicsRef
          .where('category', isEqualTo: category.firestoreValue)
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 4));

      final topics =
          snapshot.docs.map(ForumTopic.fromFirestore).toList(growable: true);
      topics.sort(
        (a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0),
      );
      return topics;
    } catch (_) {
      return const [];
    }
  }

  Future<ForumTopic?> fetchTopic(String topicId) async {
    try {
      final doc = await _topicsRef
          .doc(topicId)
          .get()
          .timeout(const Duration(seconds: 4));
      if (!doc.exists || doc.data() == null) return null;
      return ForumTopic.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }


  Future<List<ForumComment>> fetchComments(String topicId) async {
    try {
      final snapshot = await _commentsRef
          .where('topicId', isEqualTo: topicId)
          .limit(100)
          .get()
          .timeout(const Duration(seconds: 4));

      final comments =
          snapshot.docs.map(ForumComment.fromFirestore).toList(growable: true);
      comments.sort(
        (a, b) => (a.createdAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(b.createdAt?.millisecondsSinceEpoch ?? 0),
      );
      return comments;
    } catch (_) {
      return const [];
    }
  }

  Future<String> createTopic({
    required String title,
    required String body,
    required ForumCategory category,
    required String authorId,
    required String authorName,
    String? imageUrl,
  }) async {
    final doc = await _topicsRef.add({
      'title': title.trim(),
      'body': body.trim(),
      'category': category.firestoreValue,
      'authorId': authorId,
      'authorName': authorName,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'commentCount': 0,
    });
    return doc.id;
  }

  Future<void> addComment({
    required String topicId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final batch = _firestore.batch();
    final commentRef = _commentsRef.doc();

    batch.set(commentRef, {
      'topicId': topicId,
      'text': text.trim(),
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(_topicsRef.doc(topicId), {
      'commentCount': FieldValue.increment(1),
    });

    await batch.commit();
  }
}
