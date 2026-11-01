import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/community_post.dart';
import '../repositories/community_post_repository.dart';
import '../services/community_author_service.dart';
import '../utils/community_image_layout.dart';
import '../widgets/community_post_card.dart';
import '../widgets/community_post_composer_sheet.dart';
import '../../buyer/storefront_layout.dart';
import '../../../models/screen_guide_step.dart';
import '../../../widgets/farmer_helper_button.dart';
import '../../../utils/scroll_bottom_padding.dart';
import '../../../theme/agro_accent_colors.dart';
import '../../../widgets/agro_glass_chrome.dart';
import '../../../widgets/marketplace_pagination_bar.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  static const _chipGreen = AgroAccentColors.marketplaceChipGreen;
  static const _postsPerPage = 10;

  late final Stream<List<CommunityPost>> _feedStream;

  String _emptyFeedMessage(BuildContext context) {
    const key = 'community_empty_feed';
    final translated = key.tr();
    if (translated != key) return translated;
    return 'The feed is empty. Share the first photo from your farm!';
  }

  bool _isUploading = false;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  final CommunityAuthorService _authorService = CommunityAuthorService();
  final CommunityPostRepository _postRepository = CommunityPostRepository();
  final Set<String> _hiddenPostIds = {};

  final GlobalKey _communityFeedKey = GlobalKey();
  final GlobalKey _communityAddPostKey = GlobalKey();
  final GlobalKey _communityPaginationKey = GlobalKey();

  List<ScreenGuideStep> get _guideSteps => [
        ScreenGuideStep(
          targetKey: _communityFeedKey,
          titleKey: 'guide_community_feed_title',
          bodyKey: 'guide_community_feed_body',
        ),
        ScreenGuideStep(
          targetKey: _communityAddPostKey,
          titleKey: 'guide_community_add_post_title',
          bodyKey: 'guide_community_add_post_body',
        ),
        ScreenGuideStep(
          targetKey: _communityPaginationKey,
          titleKey: 'guide_community_pagination_title',
          bodyKey: 'guide_community_pagination_body',
        ),
      ];

  @override
  void initState() {
    super.initState();
    _feedStream = _postRepository.watchFeedPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _totalPages(int itemCount) {
    if (itemCount <= 0) return 1;
    return (itemCount / _postsPerPage).ceil();
  }

  List<CommunityPost> _pageItems(List<CommunityPost> posts, int page) {
    if (posts.isEmpty) return const [];
    final totalPages = _totalPages(posts.length);
    final safePage = page.clamp(1, totalPages);
    final start = (safePage - 1) * _postsPerPage;
    final end = math.min(start + _postsPerPage, posts.length);
    return posts.sublist(start, end);
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile == null || !mounted) return;

    final draft = await showCommunityPostComposer(
      context: context,
      initialImage: File(pickedFile.path),
    );
    if (draft == null || !mounted) return;

    await _performUpload(draft.imageFile, draft.description);
  }

  void _showImageSourcePicker() {
    if (_isUploading) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera,
                color: AgroAccentColors.marketplaceChipGreen,
              ),
              title: Text('scanner_camera'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AgroAccentColors.marketplaceChipGreen,
              ),
              title: Text('scanner_gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performUpload(File file, String description) async {
    setState(() => _isUploading = true);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      final imageAspectRatio =
          await CommunityImageLayout.readAspectRatioFromFile(file);
      final downloadUrl = await _postRepository.uploadPostImage(file);

      await _postRepository.publishPost(
        imageUrl: downloadUrl,
        description: description.isNotEmpty
            ? description
            : 'community_no_description'.tr(),
        userId: userId!,
        imageAspectRatio: imageAspectRatio,
      );

      if (mounted) {
        setState(() => _currentPage = 1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('community_post_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('community_posting_blocked')
            ? 'community_posting_blocked'.tr()
            : 'common_error'.tr(namedArgs: {'error': '$e'});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgroAccentColors.marketplaceUnifiedGreen,
      appBar: AgroGlassAppBar(
        unifiedMarketplaceHeader: true,
        title: Text('community_title'.tr()),
        actions: [
          KeyedSubtree(
            key: _communityAddPostKey,
            child: AgroHeaderIconButton(
              icon: Icons.add_a_photo,
              tooltip: 'guide_community_add_post_title'.tr(),
              onPressed: _showImageSourcePicker,
            ),
          ),
          FarmerHelperIconButton(guideSteps: _guideSteps),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AgroAccentColors.marketplaceUnifiedBackgroundGradient,
        ),
        child: StreamBuilder<List<CommunityPost>>(
        stream: _feedStream,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            return KeyedSubtree(
              key: _communityFeedKey,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _emptyFeedMessage(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _chipGreen),
            );
          }

          final allPosts = snapshot.data!
              .where((post) => !_hiddenPostIds.contains(post.id))
              .toList(growable: false);

          final totalPages = _totalPages(allPosts.length);
          final currentPage = _currentPage.clamp(1, totalPages);
          if (currentPage != _currentPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _currentPage = currentPage);
            });
          }

          final pagePosts = _pageItems(allPosts, currentPage);

          if (allPosts.isEmpty) {
            return KeyedSubtree(
              key: _communityFeedKey,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _emptyFeedMessage(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            );
          }

          return KeyedSubtree(
            key: _communityFeedKey,
            child: ListView.builder(
              controller: _scrollController,
              padding: ScrollBottomPadding.list(
                context,
                base: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                mainTab: true,
              ),
              itemCount: pagePosts.length + (totalPages > 1 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == pagePosts.length) {
                  return KeyedSubtree(
                    key: _communityPaginationKey,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: MarketplacePaginationBar(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        onPageSelected: _goToPage,
                        compactNavigation: true,
                      ),
                    ),
                  );
                }

                final post = pagePosts[index];
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: StorefrontLayout.maxContentWidth,
                    ),
                    child: CommunityPostCard(
                      post: post,
                      authorService: _authorService,
                      postRepository: _postRepository,
                      onReported: () {
                        setState(() => _hiddenPostIds.add(post.id));
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      ),
    );
  }
}
