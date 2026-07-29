import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/community_post.dart';
import '../repositories/community_post_repository.dart';
import '../services/community_author_service.dart';
import '../widgets/community_post_card.dart';
import '../../../models/screen_guide_step.dart';
import '../../../widgets/farmer_helper_button.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  static const _postsPerPage = 10;

  String _emptyFeedMessage(BuildContext context) {
    const key = 'community_empty_feed';
    final translated = key.tr();
    if (translated != key) return translated;
    return 'The feed is empty. Share the first photo from your farm!';
  }

  bool _isUploading = false;
  int _currentPage = 1;
  final TextEditingController _descriptionController = TextEditingController();
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
  void dispose() {
    _descriptionController.dispose();
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

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed:
                currentPage > 1 ? () => _goToPage(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            label: Text(
              'page_previous'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green[800],
              disabledForegroundColor: Colors.grey[400],
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalPages, (index) {
                  final pageNumber = index + 1;
                  final isActive = pageNumber == currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: isActive ? null : () => _goToPage(pageNumber),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              isActive ? Colors.blue[700] : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? Colors.blue[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          '$pageNumber',
                          style: TextStyle(
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.w500,
                            color: isActive ? Colors.white : Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: currentPage < totalPages
                ? () => _goToPage(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            label: Text(
              'page_next'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(
              foregroundColor: Colors.green[800],
              disabledForegroundColor: Colors.grey[400],
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDescriptionDialog(File imageFile) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: bottomInset),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AlertDialog(
            title: Text('community_add_description'.tr()),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      imageFile,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'community_description_hint'.tr(),
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _descriptionController.clear();
                  Navigator.pop(context);
                },
                child: Text('cart_cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performUpload(imageFile);
                },
                child: Text('community_publish'.tr()),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);

    if (pickedFile != null) {
      _showDescriptionDialog(File(pickedFile.path));
    }
  }

  Future<void> _performUpload(File file) async {
    setState(() => _isUploading = true);
    final description = _descriptionController.text.trim();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      final fileName = 'ljepote/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final task = FirebaseStorage.instance.ref().child(fileName).putFile(
            file,
            SettableMetadata(contentType: 'image/jpeg'),
          );

      final snapshot = await task;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _postRepository.publishPost(
        imageUrl: downloadUrl,
        description: description.isNotEmpty
            ? description
            : 'community_no_description'.tr(),
        userId: userId!,
      );

      _descriptionController.clear();
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
      appBar: AppBar(
        title: Text('community_title'.tr()),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          FarmerHelperIconButton(guideSteps: _guideSteps),
        ],
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: _postRepository.watchFeedPosts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
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
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: _communityFeedKey,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    itemCount: pagePosts.length,
                    itemBuilder: (context, index) {
                      final post = pagePosts[index];
                      return CommunityPostCard(
                        post: post,
                        authorService: _authorService,
                        postRepository: _postRepository,
                        onReported: () {
                          setState(() => _hiddenPostIds.add(post.id));
                        },
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 4),
                child: KeyedSubtree(
                  key: _communityPaginationKey,
                  child: _buildPaginationBar(
                    currentPage: currentPage,
                    totalPages: totalPages,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: KeyedSubtree(
        key: _communityAddPostKey,
        child: FloatingActionButton(
          onPressed: _isUploading ? null : _pickImage,
          backgroundColor: Colors.green[800],
          child: _isUploading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Icon(Icons.add_a_photo, color: Colors.white),
        ),
      ),
    );
  }
}
