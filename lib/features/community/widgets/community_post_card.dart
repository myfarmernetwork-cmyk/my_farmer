import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/post_author.dart';
import '../repositories/community_post_repository.dart';
import '../services/community_author_service.dart';
import '../utils/community_formatters.dart';
import '../utils/community_location_launcher.dart';
import '../../../widgets/profile_avatar.dart';
import 'community_applause_bar.dart';

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
                authorId: post.authorId,
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
            SizedBox(
              width: double.infinity,
              height: 250,
              child: Image.network(
                post.imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: Colors.green.shade700,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey.shade500, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'community_image_load_error'.tr(),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
          CommunityApplauseBar(
            post: post,
            postRepository: postRepository,
          ),
        ],
      ),
    );
  }
}

class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({
    required this.author,
    required this.authorId,
    required this.postedAt,
    required this.isLoading,
    required this.onReport,
  });

  final PostAuthor? author;
  final String? authorId;
  final String postedAt;
  final bool isLoading;
  final VoidCallback onReport;

  Future<void> _openLocationOnMap(BuildContext context) async {
    final location = author?.location?.trim();
    if (author?.hasMapLocation != true) return;

    final opened = await openCommunityLocationOnMap(
      locationLabel: location ?? '',
      lat: author?.farmLat,
      lng: author?.farmLng,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('community_location_open_failed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = author?.role;
    final roleLabel = CommunityFormatters.roleLabel(role);
    final roleColor = CommunityFormatters.roleColor(role);
    final displayName = author?.displayName ?? 'common_user'.tr();
    final location = author?.location?.trim();
    final canOpenLocation = author?.hasMapLocation == true;

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
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2),
                  child: ProfileAvatar(
                    imageUrl: author?.profileImageUrl,
                    radius: 20,
                    backgroundColor: roleColor.withValues(alpha: 0.15),
                    iconColor: roleColor,
                    iconSize: 22,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey.shade700,
                              size: 22,
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
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
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
                      ),
                      if (location != null && location.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canOpenLocation
                                ? () => _openLocationOnMap(context)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: canOpenLocation
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        color: canOpenLocation
                                            ? Colors.green.shade800
                                            : Colors.grey.shade700,
                                        decoration: canOpenLocation
                                            ? TextDecoration.underline
                                            : null,
                                        decorationColor: Colors.green.shade600,
                                      ),
                                    ),
                                  ),
                                  if (canOpenLocation)
                                    Icon(
                                      Icons.open_in_new,
                                      size: 14,
                                      color: Colors.green.shade700,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (postedAt.isNotEmpty) ...[
                        const SizedBox(height: 6),
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
                ),
              ],
            ),
    );
  }
}
