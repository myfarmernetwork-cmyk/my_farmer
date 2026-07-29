import 'package:cloud_firestore/cloud_firestore.dart';

class ForumComment {
  const ForumComment({
    required this.id,
    required this.topicId,
    required this.text,
    required this.authorId,
    required this.authorName,
    this.createdAt,
  });

  final String id;
  final String topicId;
  final String text;
  final String authorId;
  final String authorName;
  final Timestamp? createdAt;

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
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
