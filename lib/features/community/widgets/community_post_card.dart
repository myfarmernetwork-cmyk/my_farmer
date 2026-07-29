import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/post_author.dart';
import '../repositories/community_post_repository.dart';
import '../services/community_author_service.dart';
import '../utils/community_formatters.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.authorService,
    required this.postRepository,
    this.onReported,
  });

  final CommunityPost post;
  final CommunityAuthorService authorService;
  final CommunityPostRepository postRepository;
  final VoidCallback? onReported;

  Future<void> _reportPost(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('community_report_login_required'.tr())),
      );
      return;
    }

    if (post.authorId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('community_report_own_post'.tr())),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('community_report_confirm_title'.tr()),
        content: Text('community_report_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('community_report_post'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await postRepository.reportPost(
        postId: post.id,
        reporterId: user.uid,
      );
      onReported?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('community_report_success'.tr()),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<PostAuthor?>(
            future: authorService.getAuthor(post.authorId),
            builder: (context, snapshot) {
              final author = snapshot.data;
              return _AuthorHeader(
                author: author,
                postedAt: CommunityFormatters.relativeTime(
                  context,
                  post.timestamp,
                ),
                isLoading: snapshot.connectionState == ConnectionState.waiting &&
                    author == null,
                onReport: () => _reportPost(context),
              );
            },
          ),
          if (post.imageUrl.isNotEmpty)
            Image.network(
              post.imageUrl,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image, color: Colors.grey.shade500),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              post.description.isNotEmpty
                  ? post.description
                  : 'community_no_description'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({
    required this.author,
    required this.postedAt,
    required this.isLoading,
    required this.onReport,
  });

  final PostAuthor? author;
  final String postedAt;
  final bool isLoading;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final role = author?.role;
    final roleLabel = CommunityFormatters.roleLabel(role);
    final roleColor = CommunityFormatters.roleColor(role);
    final displayName = author?.displayName ?? 'common_user'.tr();
    final location = author?.location;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.green.shade100),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 42,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: roleColor.withValues(alpha: 0.15),
                      child: Icon(Icons.person, color: roleColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (location != null && location.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade700,
                      ),
                      onSelected: (value) {
                        if (value == 'report') onReport();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(
                                Icons.flag_outlined,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text('community_report_post'.tr()),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: roleColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (postedAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    postedAt,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
