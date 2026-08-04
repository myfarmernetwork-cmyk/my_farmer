import 'package:cloud_firestore/cloud_firestore.dart';

import 'forum_category.dart';

class ForumTopic {
  const ForumTopic({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.authorId,
    required this.authorName,
    this.imageUrl,
    this.linkUrl,
    this.createdAt,
    this.updatedAt,
    this.commentCount = 0,
  });

  final String id;
  final String title;
  final String body;
  final ForumCategory category;
  final String authorId;
  final String authorName;
  final String? imageUrl;
  final String? linkUrl;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final int commentCount;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  bool get hasLink => linkUrl != null && linkUrl!.trim().isNotEmpty;

  factory ForumTopic.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ForumTopic(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      category: ForumCategoryX.fromFirestore(data['category']?.toString()),
      authorId: data['authorId']?.toString() ?? '',
      authorName: data['authorName']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
      linkUrl: data['linkUrl']?.toString(),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
    );
  }
}
