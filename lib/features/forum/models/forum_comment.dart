import 'package:cloud_firestore/cloud_firestore.dart';

class ForumComment {
  const ForumComment({
    required this.id,
    required this.topicId,
    required this.text,
    required this.authorId,
    required this.authorName,
    this.imageUrl,
    this.linkUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String topicId;
  final String text;
  final String authorId;
  final String authorName;
  final String? imageUrl;
  final String? linkUrl;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  bool get hasLink => linkUrl != null && linkUrl!.trim().isNotEmpty;

  factory ForumComment.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return ForumComment(
      id: doc.id,
      topicId: data['topicId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      authorId: data['authorId']?.toString() ?? '',
      authorName: data['authorName']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
      linkUrl: data['linkUrl']?.toString(),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
}
