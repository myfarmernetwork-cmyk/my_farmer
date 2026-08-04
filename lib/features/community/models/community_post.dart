import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../utils/firestore_parse.dart';

class CommunityPost {
  final String id;
  final String imageUrl;
  final String description;
  final String? authorId;
  final Timestamp? timestamp;
  final bool isReported;
  final List<String> reportedBy;
  final List<String> applaudedBy;

  const CommunityPost({
    required this.id,
    required this.imageUrl,
    required this.description,
    this.authorId,
    this.timestamp,
    this.isReported = false,
    this.reportedBy = const [],
    this.applaudedBy = const [],
  });

  int get applauseCount => applaudedBy.length;

  bool hasApplauded(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return applaudedBy.contains(userId);
  }

  factory CommunityPost.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = FirestoreParse.mapOrEmpty(doc.data());

    return CommunityPost(
      id: doc.id,
      imageUrl: FirestoreParse.stringOrEmpty(data['imageUrl']),
      description: FirestoreParse.stringOrEmpty(data['description']),
      authorId: FirestoreParse.optionalString(
            data['authorId'] ?? data['userId'],
          ),
      timestamp: FirestoreParse.timestampOrNull(data['timestamp']),
      isReported: FirestoreParse.boolOr(data['isReported']),
      reportedBy: FirestoreParse.stringListOrEmpty(data['reportedBy']),
      applaudedBy: FirestoreParse.stringListOrEmpty(data['applaudedBy']),
    );
  }

  static CommunityPost? tryFromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return CommunityPost.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }
}
