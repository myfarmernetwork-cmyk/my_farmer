import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../community/models/community_post.dart';
import '../community/repositories/community_post_repository.dart';
import '../community/services/community_author_service.dart';
import '../community/utils/community_formatters.dart';

class AdminReportedPostsScreen extends StatefulWidget {
  const AdminReportedPostsScreen({super.key});

  @override
  State<AdminReportedPostsScreen> createState() =>
      _AdminReportedPostsScreenState();
}

class _AdminReportedPostsScreenState extends State<AdminReportedPostsScreen> {
  final _repository = CommunityPostRepository();
  final _authorService = CommunityAuthorService();
  final Set<String> _processing = {};

  Future<void> _dismiss(CommunityPost post) async {
    setState(() => _processing.add(post.id));
    try {
      await _repository.dismissReport(post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin_report_dismissed'.tr()),
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
      if (mounted) setState(() => _processing.remove(post.id));
    }
  }

  Future<void> _deletePermanently(CommunityPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin_report_delete_title'.tr()),
        content: Text('admin_report_delete_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('admin_report_delete_confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing.add(post.id));
    try {
      await _repository.deletePostPermanently(
        postId: post.id,
        authorId: post.authorId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin_report_deleted'.tr()),
          backgroundColor: Colors.red.shade700,
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
      if (mounted) setState(() => _processing.remove(post.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('admin_reported_posts_title'.tr()),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: _repository.watchReportedPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'common_error'.tr(
                  namedArgs: {'error': '${snapshot.error}'},
                ),
              ),
            );
          }

          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'admin_reported_posts_empty'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final isBusy = _processing.contains(post.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (post.imageUrl.isNotEmpty)
                      Image.network(
                        post.imageUrl,
                        height: 220,
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
                          FutureBuilder(
                            future: _authorService.getAuthor(post.authorId),
                            builder: (context, authorSnapshot) {
                              final author = authorSnapshot.data;
                              return Text(
                                author?.displayName ?? 'common_user'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              );
                            },
                          ),
                          if (post.timestamp != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              CommunityFormatters.relativeTime(
                                context,
                                post.timestamp,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            post.description.isNotEmpty
                                ? post.description
                                : 'community_no_description'.tr(),
                          ),
                          if (post.reportedBy.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'admin_report_count'.tr(
                                namedArgs: {
                                  'count': '${post.reportedBy.length}',
                                },
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      isBusy ? null : () => _dismiss(post),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: Text('admin_report_dismiss'.tr()),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isBusy
                                      ? null
                                      : () => _deletePermanently(post),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.delete_forever),
                                  label: Text('admin_report_delete'.tr()),
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
            },
          );
        },
      ),
    );
  }
}
