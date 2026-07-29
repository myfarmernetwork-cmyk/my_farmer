import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_author.dart';

class CommunityAuthorService {
  CommunityAuthorService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Map<String, PostAuthor?> _cache = {};

  Future<PostAuthor?> getAuthor(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    if (_cache.containsKey(userId)) return _cache[userId];

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) {
        _cache[userId] = null;
        return null;
      }
      final author = PostAuthor.fromMap(userId, doc.data()!);
      _cache[userId] = author;
      return author;
    } catch (_) {
      _cache[userId] = null;
      return null;
    }
  }

  void clearCache() => _cache.clear();
}
