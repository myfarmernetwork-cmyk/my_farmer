import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  final String id;
  final String imageUrl;
  final String description;
  final String? authorId;
  final Timestamp? timestamp;
  final bool isReported;
  final List<String> reportedBy;

  const CommunityPost({
    required this.id,
    required this.imageUrl,
    required this.description,
    this.authorId,
    this.timestamp,
    this.isReported = false,
    this.reportedBy = const [],
  });

  factory CommunityPost.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final reportedRaw = data['reportedBy'];
    final reportedBy = reportedRaw is List
        ? reportedRaw.map((e) => e.toString()).toList()
        : <String>[];

    return CommunityPost(
      id: doc.id,
      imageUrl: data['imageUrl']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      authorId: data['authorId']?.toString() ?? data['userId']?.toString(),
      timestamp: data['timestamp'] as Timestamp?,
      isReported: data['isReported'] as bool? ?? false,
      reportedBy: reportedBy,
    );
  }
}
