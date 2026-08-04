import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../buyer/storefront_layout.dart';
import '../../buyer/widgets/storefront_loading_view.dart';
import '../../../utils/firestore_error_helper.dart';
import '../../../widgets/firestore_error_panel.dart';
import '../models/community_post.dart';
import '../repositories/community_post_repository.dart';
import '../utils/community_formatters.dart';
import 'community_applause_bar.dart';

class UserCommunityGalleryGrid extends StatelessWidget {
  const UserCommunityGalleryGrid({
    super.key,
    required this.userId,
    this.storefrontScrollable = false,
  });

  final String userId;

  /// When true, fills a storefront tab via [CustomScrollView] (no [NestedScrollView]).
  final bool storefrontScrollable;

  static SliverGridDelegate gridDelegateForWidth(double width) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: StorefrontLayout.galleryCrossAxisCount(width),
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = CommunityPostRepository();

    return LayoutBuilder(
      builder: (context, constraints) {
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
              return _wrapBody(context, constraints, panel);
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              if (storefrontScrollable) {
                return ColoredBox(
                  color: Colors.white,
                  child: StorefrontGalleryLoadingView(
                    scrollable: true,
                    width: constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : null,
                  ),
                );
              }
              return _wrapBody(
                context,
                constraints,
                const StorefrontGalleryLoadingView(scrollable: false),
              );
            }

            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return _wrapStorefrontState(
                constraints: constraints,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined,
                            size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'profile_gallery_empty'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final gridDelegate = gridDelegateForWidth(constraints.maxWidth);

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

            return ColoredBox(
              color: Colors.white,
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
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
      color: Colors.white,
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
      return ColoredBox(color: Colors.white, child: child);
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (post.imageUrl.isNotEmpty)
                Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 220,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.timestamp != null)
                      Text(
                        CommunityFormatters.relativeTime(
                          context,
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
                      postRepository: CommunityPostRepository(),
                    ),
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
              : Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: Colors.grey.shade200,
                    child: Icon(Icons.broken_image, color: Colors.grey.shade500),
                  ),
                ),
        ),
      ),
    );
  }
}
