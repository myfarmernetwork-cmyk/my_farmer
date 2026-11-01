import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../buyer/storefront_layout.dart';
import '../../buyer/widgets/storefront_loading_view.dart';
import '../../../widgets/firestore_error_panel.dart';
import '../../../utils/scroll_bottom_padding.dart';
import '../models/community_post.dart';
import '../repositories/community_post_repository.dart';
import '../services/community_post_actions.dart';
import '../utils/community_formatters.dart';
import 'community_applause_bar.dart';
import 'community_gallery_image.dart';

class UserCommunityGalleryGrid extends StatelessWidget {
  const UserCommunityGalleryGrid({
    super.key,
    required this.userId,
    this.storefrontScrollable = false,
    this.profileTab = false,
  });

  final String userId;

  /// When true, fills a storefront tab via [CustomScrollView] (no [NestedScrollView]).
  final bool storefrontScrollable;

  /// Profil tab — transparentna pozadina na gradijentu + padding iznad navigacije.
  final bool profileTab;

  static SliverGridDelegate gridDelegateForWidth(double width) {
    return StorefrontLayout.galleryGridDelegate(width);
  }

  double _layoutWidth(BoxConstraints constraints) {
    if (!constraints.maxWidth.isFinite) {
      return StorefrontLayout.maxContentWidth;
    }
    return constraints.maxWidth.clamp(0.0, StorefrontLayout.maxContentWidth);
  }

  @override
  Widget build(BuildContext context) {
    final repository = CommunityPostRepository();

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutWidth = _layoutWidth(constraints);

        Widget buildContent(Widget child) {
          if (storefrontScrollable) return child;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: layoutWidth, child: child),
          );
        }

        return StreamBuilder<List<CommunityPost>>(
          stream: repository.watchUserGallery(userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final panel = FirestoreErrorPanel(
                error: snapshot.error!,
                compact: true,
              );
              if (storefrontScrollable) {
                return _wrapStorefrontState(
                  constraints: constraints,
                  child: panel,
                );
              }
              return buildContent(_wrapBody(context, constraints, panel));
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              if (storefrontScrollable) {
                return ColoredBox(
                  color: Colors.white,
                  child: StorefrontGalleryLoadingView(
                    scrollable: true,
                    width: layoutWidth,
                  ),
                );
              }
              return buildContent(
                _wrapBody(
                  context,
                  constraints,
                  StorefrontGalleryLoadingView(
                    scrollable: false,
                    width: layoutWidth,
                  ),
                ),
              );
            }

            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return buildContent(_wrapStorefrontState(
                constraints: constraints,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 56,
                          color: profileTab
                              ? Colors.white.withValues(alpha: 0.45)
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'profile_gallery_empty'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: profileTab
                                ? Colors.white.withValues(alpha: 0.85)
                                : Colors.grey.shade600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ));
            }

            final gridDelegate = gridDelegateForWidth(layoutWidth);

            if (storefrontScrollable) {
              return ColoredBox(
                color: Colors.white,
                child: CustomScrollView(
                  key: PageStorageKey<String>('storefront_gallery_$userId'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(8),
                      sliver: SliverGrid(
                        gridDelegate: gridDelegate,
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final post = posts[index];
                            return _GalleryTile(
                              post: post,
                              onTap: () => _showPostPreview(context, post),
                            );
                          },
                          childCount: posts.length,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return buildContent(
              ColoredBox(
                color: profileTab ? Colors.transparent : Colors.white,
                child: GridView.builder(
                  padding: profileTab
                      ? ScrollBottomPadding.list(
                          context,
                          mainTab: true,
                          base: const EdgeInsets.all(8),
                        )
                      : const EdgeInsets.all(8),
                  gridDelegate: gridDelegate,
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _GalleryTile(
                      post: post,
                      onTap: () => _showPostPreview(context, post),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _wrapBody(
    BuildContext context,
    BoxConstraints constraints,
    Widget child,
  ) {
    return ColoredBox(
      color: profileTab ? Colors.transparent : Colors.white,
      child: SizedBox(
        width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
        child: child,
      ),
    );
  }

  Widget _wrapStorefrontState({
    required BoxConstraints constraints,
    required Widget child,
  }) {
    if (!storefrontScrollable) {
      return ColoredBox(
        color: profileTab ? Colors.transparent : Colors.white,
        child: child,
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox(
              width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  void _showPostPreview(BuildContext context, CommunityPost post) {
    final repository = CommunityPostRepository();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwnPost =
        currentUid != null && currentUid.isNotEmpty && post.authorId == currentUid;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (post.imageUrl.isNotEmpty)
                CommunityGalleryImagePreview(imageUrl: post.imageUrl),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.timestamp != null)
                      Text(
                        CommunityFormatters.relativeTime(
                          dialogContext,
                          post.timestamp,
                        ),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      post.description.isNotEmpty
                          ? post.description
                          : 'community_no_description'.tr(),
                      style: const TextStyle(fontSize: 15),
                    ),
                    CommunityApplauseBar(
                      post: post,
                      postRepository: repository,
                    ),
                    if (isOwnPost) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                await CommunityPostActions.editPost(
                                  context,
                                  post,
                                  repository,
                                );
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: Text('community_edit_post'.tr()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                await CommunityPostActions.deletePost(
                                  context,
                                  post,
                                  repository,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                              ),
                              icon: const Icon(Icons.delete_outline),
                              label: Text('community_delete_post'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.post,
    required this.onTap,
  });

  final CommunityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1,
          child: post.imageUrl.isEmpty
              ? ColoredBox(
                  color: Colors.grey.shade200,
                  child: Icon(Icons.image_not_supported,
                      color: Colors.grey.shade500),
                )
              : CommunityGalleryImage(
                  imageUrl: post.imageUrl,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                ),
        ),
      ),
    );
  }
}
