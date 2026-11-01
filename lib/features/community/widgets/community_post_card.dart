import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../buyer/farmer_storefront_screen.dart';
import '../models/community_post.dart';
import '../models/post_author.dart';
import '../repositories/community_post_repository.dart';
import '../services/community_author_service.dart';
import '../services/community_post_actions.dart';
import '../utils/community_formatters.dart';
import '../utils/community_image_layout.dart';
import '../utils/community_location_launcher.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../providers/subscription_provider.dart';
import '../../../theme/agro_accent_colors.dart';
import 'community_applause_bar.dart';
import 'community_gallery_image.dart';

class CommunityPostCard extends ConsumerWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.authorService,
    required this.postRepository,
    this.onReported,
    this.onDeleted,
  });

  final CommunityPost post;
  final CommunityAuthorService authorService;
  final CommunityPostRepository postRepository;
  final VoidCallback? onReported;
  final VoidCallback? onDeleted;

  bool get _isOwnPost {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid.isNotEmpty && post.authorId == uid;
  }

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

  Future<void> _editPost(BuildContext context) async {
    await CommunityPostActions.editPost(context, post, postRepository);
  }

  Future<void> _deletePost(BuildContext context, {required bool asAdmin}) async {
    if (asAdmin) {
      await CommunityPostActions.deletePostAsAdmin(context, post, postRepository);
    } else {
      await CommunityPostActions.deletePost(context, post, postRepository);
    }
    onDeleted?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(adminPremiumBypassProvider);
    const chipGreen = AgroAccentColors.marketplaceChipGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AgroAccentColors.marketplaceCornerRadius,
        ),
        side: BorderSide(color: chipGreen.withValues(alpha: 0.22)),
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
                isOwnPost: _isOwnPost,
                canAdminDelete: isAdmin && !_isOwnPost,
                onReport: () => _reportPost(context),
                onEdit: () => _editPost(context),
                onDelete: () => _deletePost(
                  context,
                  asAdmin: isAdmin && !_isOwnPost,
                ),
              );
            },
          ),
          if (post.imageUrl.isNotEmpty)
            CommunityFeedImage(
              imageUrl: post.imageUrl,
              storedAspectRatio: post.imageAspectRatio,
              errorBuilder: (_, __, ___) => AspectRatio(
                aspectRatio: CommunityImageLayout.defaultAspectRatio,
                child: ColoredBox(
                  color: Colors.grey.shade200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image,
                          color: Colors.grey.shade500, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'community_image_load_error'.tr(),
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          CommunityApplauseBar(
            post: post,
            postRepository: postRepository,
          ),
        ],
      ),
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
    required this.isOwnPost,
    required this.canAdminDelete,
    required this.onReport,
    required this.onEdit,
    required this.onDelete,
  });

  final PostAuthor? author;
  final String? authorId;
  final String postedAt;
  final bool isLoading;
  final bool isOwnPost;
  final bool canAdminDelete;
  final VoidCallback onReport;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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

  void _openAuthorProfile(BuildContext context) {
    final id = authorId?.trim();
    if (id == null || id.isEmpty) return;
    if (!CommunityFormatters.hasPublicProfile(author?.role)) return;
    openSellerProfile(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final role = author?.role;
    final roleLabel = CommunityFormatters.roleLabel(role);
    final roleColor = CommunityFormatters.roleColor(role);
    final displayName = author?.displayName ?? 'common_user'.tr();
    final location = author?.location?.trim();
    final canOpenLocation = author?.hasMapLocation == true;
    final canOpenProfile = CommunityFormatters.hasPublicProfile(role);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: AgroAccentColors.marketplaceChipGreen.withValues(alpha: 0.15),
          ),
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
                  child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AgroAccentColors.marketplaceChipGreen,
                ),
                ),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: canOpenProfile
                          ? () => _openAuthorProfile(context)
                          : null,
                      customBorder: const CircleBorder(),
                      child: ProfileAvatar(
                        imageUrl: author?.profileImageUrl,
                        radius: 20,
                        backgroundColor: roleColor.withValues(alpha: 0.15),
                        iconColor: roleColor,
                        iconSize: 22,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: canOpenProfile
                                    ? () => _openAuthorProfile(context)
                                    : null,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: canOpenProfile
                                          ? AgroAccentColors.marketplaceChipGreen
                                          : Colors.grey.shade800,
                                      decoration: canOpenProfile
                                          ? TextDecoration.underline
                                          : null,
                                      decorationColor:
                                          AgroAccentColors.marketplaceChipGreen,
                                    ),
                                  ),
                                ),
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
                              color: AgroAccentColors.marketplaceChipGreen,
                              size: 22,
                            ),
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  onEdit();
                                  break;
                                case 'delete':
                                  onDelete();
                                  break;
                                case 'report':
                                  onReport();
                                  break;
                              }
                            },
                            itemBuilder: (context) {
                              if (isOwnPost) {
                                return [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit_outlined,
                                          color: AgroAccentColors.marketplaceChipGreen,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('community_edit_post'.tr()),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('community_delete_post'.tr()),
                                      ],
                                    ),
                                  ),
                                ];
                              }

                              if (canAdminDelete) {
                                return [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('community_admin_delete_post'.tr()),
                                      ],
                                    ),
                                  ),
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
                                ];
                              }

                              return [
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
                              ];
                            },
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
                                        ? AgroAccentColors.marketplaceChipGreen
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
                                            ? AgroAccentColors.marketplaceChipGreen
                                            : Colors.grey.shade700,
                                        decoration: canOpenLocation
                                            ? TextDecoration.underline
                                            : null,
                                        decorationColor:
                                            AgroAccentColors.marketplaceChipGreen,
                                      ),
                                    ),
                                  ),
                                  if (canOpenLocation)
                                    Icon(
                                      Icons.open_in_new,
                                      size: 14,
                                      color: AgroAccentColors.marketplaceChipGreen,
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
