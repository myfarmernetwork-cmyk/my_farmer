import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/forum_comment.dart';
import '../models/forum_topic.dart';
import '../repositories/forum_repository.dart';

class ForumTopicDetailScreen extends StatefulWidget {
  const ForumTopicDetailScreen({
    super.key,
    required this.topicId,
  });

  final String topicId;

  @override
  State<ForumTopicDetailScreen> createState() => _ForumTopicDetailScreenState();
}

class _ForumTopicDetailScreenState extends State<ForumTopicDetailScreen> {
  final ForumRepository _repository = ForumRepository();
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;
  ForumTopic? _topic;
  List<ForumComment> _comments = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final topic = await _repository.fetchTopic(widget.topicId);
    final comments = await _repository.fetchComments(widget.topicId);
    if (!mounted) return;
    setState(() {
      _topic = topic;
      _comments = comments;
      _loaded = true;
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null) return;

    setState(() => _isSending = true);
    try {
      final authorName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'forum_anonymous'.tr();

      await _repository.addComment(
        topicId: widget.topicId,
        text: text,
        authorId: user.uid,
        authorName: authorName,
      );
      _commentController.clear();
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('forum_topic_detail'.tr()),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: !_loaded
          ? Center(child: Text('forum_topic_not_found'.tr()))
          : _topic == null
              ? Center(child: Text('forum_topic_not_found'.tr()))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            _topic!.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _topic!.authorName.isNotEmpty
                                ? _topic!.authorName
                                : 'forum_anonymous'.tr(),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          if (_topic!.imageUrl != null &&
                              _topic!.imageUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _topic!.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          if (_topic!.imageUrl != null &&
                              _topic!.imageUrl!.isNotEmpty)
                            const SizedBox(height: 16),
                          Text(
                            _topic!.body,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          const Divider(height: 32),
                          Text(
                            'forum_comments'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_comments.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'forum_no_comments'.tr(),
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _comments.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    comment.authorName.isNotEmpty
                                        ? comment.authorName
                                        : 'forum_anonymous'.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(comment.text),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: InputDecoration(
                                  hintText: 'forum_comment_hint'.tr(),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _isSending ? null : _sendComment,
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
