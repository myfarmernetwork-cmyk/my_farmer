import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../repositories/admin_repository.dart';
import '../../utils/scroll_bottom_padding.dart';

enum AdminMediaTab { gallery, products }

class AdminMediaModerationScreen extends StatefulWidget {
  const AdminMediaModerationScreen({
    super.key,
    this.userId,
    this.userName,
    this.initialTab = AdminMediaTab.gallery,
  });

  final String? userId;
  final String? userName;
  final AdminMediaTab initialTab;

  @override
  State<AdminMediaModerationScreen> createState() =>
      _AdminMediaModerationScreenState();
}

class _AdminMediaModerationScreenState extends State<AdminMediaModerationScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AdminRepository();
  final Set<String> _processing = {};
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == AdminMediaTab.products ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.userName != null && widget.userName!.trim().isNotEmpty) {
      return 'admin_user_media_title'.tr(
        namedArgs: {'name': widget.userName!.trim()},
      );
    }
    return 'admin_media_moderation_title'.tr();
  }

  Future<bool> _confirm({
    required String titleKey,
    required String bodyKey,
    required String confirmKey,
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titleKey.tr()),
        content: Text(bodyKey.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmKey.tr()),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _runAction({
    required String id,
    required Future<void> Function() action,
    required String successKey,
  }) async {
    setState(() => _processing.add(id));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successKey.tr()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(id));
    }
  }

  Future<void> _clearGalleryImage(String postId) async {
    if (!await _confirm(
      titleKey: 'admin_remove_post_image_title',
      bodyKey: 'admin_remove_post_image_body',
      confirmKey: 'admin_remove_post_image_confirm',
      confirmColor: Colors.orange.shade800,
    )) {
      return;
    }
    await _runAction(
      id: postId,
      action: () => _repo.clearCommunityPostImage(postId: postId),
      successKey: 'admin_remove_post_image_success',
    );
  }

  Future<void> _deleteGalleryPost(String postId) async {
    if (!await _confirm(
      titleKey: 'admin_delete_gallery_post_title',
      bodyKey: 'admin_delete_gallery_post_body',
      confirmKey: 'admin_delete_gallery_post_confirm',
    )) {
      return;
    }
    await _runAction(
      id: postId,
      action: () => _repo.deleteCommunityPost(postId: postId),
      successKey: 'admin_delete_gallery_post_success',
    );
  }

  Future<void> _clearProductImage(String productId) async {
    if (!await _confirm(
      titleKey: 'admin_remove_product_image_title',
      bodyKey: 'admin_remove_product_image_body',
      confirmKey: 'admin_remove_product_image_confirm',
      confirmColor: Colors.orange.shade800,
    )) {
      return;
    }
    await _runAction(
      id: productId,
      action: () => _repo.clearProductImage(productId: productId),
      successKey: 'admin_remove_product_image_success',
    );
  }

  Future<void> _deleteProduct(String productId) async {
    if (!await _confirm(
      titleKey: 'admin_delete_product_title',
      bodyKey: 'admin_delete_product_body',
      confirmKey: 'admin_delete_product_confirm',
    )) {
      return;
    }
    await _runAction(
      id: productId,
      action: () => _repo.deleteProduct(productId: productId),
      successKey: 'admin_delete_product_success',
    );
  }

  Widget _galleryTab() {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _repo.watchCommunityPostsForAdmin(userId: widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('common_error'.tr(
              namedArgs: {'error': '${snapshot.error}'},
            )),
          );
        }

        final docs = (snapshot.data ?? [])
            .where((doc) {
              final url = doc.data()['imageUrl']?.toString().trim() ?? '';
              return url.isNotEmpty;
            })
            .toList();

        if (docs.isEmpty) {
          return Center(child: Text('admin_gallery_empty'.tr()));
        }

        return ListView.separated(
          padding: ScrollBottomPadding.list(context),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final postId = doc.id;
            final imageUrl = data['imageUrl']?.toString() ?? '';
            final description = data['description']?.toString().trim() ?? '';
            final authorId =
                data['authorId']?.toString() ?? data['userId']?.toString() ?? '';
            final isBusy = _processing.contains(postId);

            return _MediaModerationCard(
              imageUrl: imageUrl,
              title: description.isNotEmpty
                  ? description
                  : 'community_no_description'.tr(),
              subtitle: authorId.isNotEmpty ? 'ID: $authorId' : null,
              isBusy: isBusy,
              onRemoveImage: () => _clearGalleryImage(postId),
              onDeleteItem: () => _deleteGalleryPost(postId),
            );
          },
        );
      },
    );
  }

  Widget _productsTab() {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _repo.watchProductsForAdmin(sellerId: widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('common_error'.tr(
              namedArgs: {'error': '${snapshot.error}'},
            )),
          );
        }

        final docs = (snapshot.data ?? [])
            .where((doc) {
              final url = doc.data()['imageUrl']?.toString().trim() ?? '';
              return url.isNotEmpty;
            })
            .toList();

        if (docs.isEmpty) {
          return Center(child: Text('admin_products_empty'.tr()));
        }

        return ListView.separated(
          padding: ScrollBottomPadding.list(context),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final productId = doc.id;
            final imageUrl = data['imageUrl']?.toString() ?? '';
            final name = data['name']?.toString().trim() ?? '—';
            final sellerName = data['sellerName']?.toString().trim() ?? '';
            final sellerId = data['sellerId']?.toString() ?? '';
            final isBusy = _processing.contains(productId);

            return _MediaModerationCard(
              imageUrl: imageUrl,
              title: name,
              subtitle: [
                if (sellerName.isNotEmpty) sellerName,
                if (sellerId.isNotEmpty) 'ID: $sellerId',
              ].join(' · '),
              isBusy: isBusy,
              onRemoveImage: () => _clearProductImage(productId),
              onDeleteItem: () => _deleteProduct(productId),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'admin_media_tab_gallery'.tr()),
            Tab(text: 'admin_media_tab_products'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _galleryTab(),
          _productsTab(),
        ],
      ),
    );
  }
}

class _MediaModerationCard extends StatelessWidget {
  const _MediaModerationCard({
    required this.imageUrl,
    required this.title,
    required this.isBusy,
    required this.onRemoveImage,
    required this.onDeleteItem,
    this.subtitle,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final bool isBusy;
  final VoidCallback onRemoveImage;
  final VoidCallback onDeleteItem;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.network(
            imageUrl,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 160,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : onRemoveImage,
                        icon: const Icon(Icons.hide_image_outlined),
                        label: Text('admin_remove_post_image'.tr()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isBusy ? null : onDeleteItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.delete_forever),
                        label: Text('admin_delete_item'.tr()),
                      ),
                    ),
                  ],
                ),
                if (isBusy) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
