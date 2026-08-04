import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/forum_comment.dart';
import '../models/forum_topic.dart';
import '../repositories/forum_repository.dart';
import '../utils/forum_author_name.dart';
import 'forum_create_topic_screen.dart';

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
  Map<String, String> _authorNames = const {};
  bool _loaded = false;

  File? _pendingImageFile;
  String? _pendingLinkUrl;
  String? _editingCommentId;
  String? _existingImageUrl;

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

    final ids = <String>{};
    if (topic != null && topic.authorId.isNotEmpty) ids.add(topic.authorId);
    for (final comment in comments) {
      if (comment.authorId.isNotEmpty) ids.add(comment.authorId);
    }
    final names = await ForumAuthorName.forUserIds(ids);

    setState(() {
      _topic = topic;
      _comments = comments;
      _authorNames = names;
      _loaded = true;
    });
  }

  String _displayName(String authorId, String storedName) {
    final resolved = _authorNames[authorId];
    return ForumAuthorName.label(
      resolved?.isNotEmpty == true ? resolved! : storedName,
      'forum_anonymous'.tr(),
    );
  }

  bool get _isTopicOwner {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && _topic?.authorId == uid;
  }

  Future<void> _editTopic() async {
    final topic = _topic;
    if (topic == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ForumCreateTopicScreen(
          category: topic.category,
          editingTopic: topic,
        ),
      ),
    );
    if (changed == true) await _loadData();
  }

  Future<void> _deleteTopic() async {
    final topic = _topic;
    if (topic == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('forum_delete_topic'.tr()),
        content: Text('forum_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'forum_delete_action'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.deleteTopic(topic.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(ForumComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('forum_delete_comment'.tr()),
        content: Text('forum_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'forum_delete_action'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.deleteComment(
        commentId: comment.id,
        topicId: widget.topicId,
      );
      if (_editingCommentId == comment.id) _clearComposer();
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
    }
  }

  void _clearComposer() {
    _commentController.clear();
    setState(() {
      _pendingImageFile = null;
      _pendingLinkUrl = null;
      _editingCommentId = null;
      _existingImageUrl = null;
    });
  }

  void _startEditing(ForumComment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _commentController.text = comment.text;
      _pendingImageFile = null;
      _existingImageUrl = comment.imageUrl;
      _pendingLinkUrl = comment.linkUrl;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() {
        _pendingImageFile = File(picked.path);
        _existingImageUrl = null;
      });
    }
  }

  Future<String?> _promptLink() async {
    final controller = TextEditingController(text: _pendingLinkUrl ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('forum_add_link'.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'forum_link_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('forum_comment_save'.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _addLink() async {
    final raw = await _promptLink();
    if (raw == null) return;
    if (raw.isEmpty) {
      setState(() => _pendingLinkUrl = null);
      return;
    }
    setState(() => _pendingLinkUrl = _normalizeLink(raw));
  }

  String _normalizeLink(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  Future<String?> _uploadImage() async {
    if (_pendingImageFile == null) return _existingImageUrl;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    final path =
        'forum_comments/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final snapshot = await FirebaseStorage.instance.ref(path).putFile(
          _pendingImageFile!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
    return snapshot.ref.getDownloadURL();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (text.isEmpty && _pendingImageFile == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('forum_comment_required'.tr())),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final authorName = ForumAuthorName.label(
        await ForumAuthorName.forCurrentUser(),
        'forum_anonymous'.tr(),
      );

      final imageUrl = await _uploadImage();
      final linkUrl = _pendingLinkUrl;
      final bodyText = text.isEmpty ? 'forum_comment_image_only'.tr() : text;

      if (_editingCommentId != null) {
        await _repository.updateComment(
          commentId: _editingCommentId!,
          text: bodyText,
          imageUrl: imageUrl,
          linkUrl: linkUrl,
          clearImage: imageUrl == null &&
              _pendingImageFile == null &&
              (_existingImageUrl == null || _existingImageUrl!.isEmpty),
          clearLink: linkUrl == null || linkUrl.isEmpty,
        );
      } else {
        await _repository.addComment(
          topicId: widget.topicId,
          text: bodyText,
          authorId: user.uid,
          authorName: authorName,
          imageUrl: imageUrl,
          linkUrl: linkUrl,
        );
      }

      _clearComposer();
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

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('forum_topic_detail'.tr()),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (_isTopicOwner) ...[
            IconButton(
              tooltip: 'forum_edit_topic'.tr(),
              onPressed: _editTopic,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'forum_delete_topic'.tr(),
              onPressed: _deleteTopic,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
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
                            _displayName(_topic!.authorId, _topic!.authorName),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          if (_topic!.updatedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'forum_comment_edited'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (_topic!.hasImage)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _topic!.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          if (_topic!.hasImage) const SizedBox(height: 16),
                          if (_topic!.hasLink) ...[
                            InkWell(
                              onTap: () => _openLink(_topic!.linkUrl!),
                              child: Row(
                                children: [
                                  Icon(Icons.link,
                                      size: 18, color: Colors.blue.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _topic!.linkUrl!,
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
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
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                final uid =
                                    FirebaseAuth.instance.currentUser?.uid;
                                final isOwn = uid == comment.authorId;
                                return _ForumCommentCard(
                                  comment: comment,
                                  authorLabel: _displayName(
                                    comment.authorId,
                                    comment.authorName,
                                  ),
                                  isOwn: isOwn,
                                  onEdit: isOwn
                                      ? () => _startEditing(comment)
                                      : null,
                                  onDelete: isOwn
                                      ? () => _deleteComment(comment)
                                      : null,
                                  onOpenLink: _openLink,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    _ForumCommentComposer(
                      controller: _commentController,
                      isSending: _isSending,
                      isEditing: _editingCommentId != null,
                      pendingImageFile: _pendingImageFile,
                      existingImageUrl: _existingImageUrl,
                      pendingLinkUrl: _pendingLinkUrl,
                      onPickImage: _pickImage,
                      onAddLink: _addLink,
                      onRemoveImage: () => setState(() {
                        _pendingImageFile = null;
                        _existingImageUrl = null;
                      }),
                      onRemoveLink: () => setState(() => _pendingLinkUrl = null),
                      onCancelEdit: _clearComposer,
                      onSubmit: _submitComment,
                    ),
                  ],
                ),
    );
  }
}

class _ForumCommentCard extends StatelessWidget {
  const _ForumCommentCard({
    required this.comment,
    required this.authorLabel,
    required this.isOwn,
    required this.onOpenLink,
    this.onEdit,
    this.onDelete,
  });

  final ForumComment comment;
  final String authorLabel;
  final bool isOwn;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Future<void> Function(String url) onOpenLink;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    authorLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (comment.updatedAt != null)
                  Text(
                    'forum_comment_edited'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (onEdit != null) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'forum_edit_comment'.tr(),
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, size: 18,
                        color: Colors.green.shade700),
                  ),
                ],
                if (onDelete != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'forum_delete_comment'.tr(),
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 18,
                        color: Colors.red.shade700),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              comment.text,
              style: const TextStyle(fontSize: 15, height: 1.45),
            ),
            if (comment.hasLink) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => onOpenLink(comment.linkUrl!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        comment.linkUrl!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          decoration: TextDecoration.underline,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (comment.hasImage) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  comment.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ForumCommentComposer extends StatelessWidget {
  const _ForumCommentComposer({
    required this.controller,
    required this.isSending,
    required this.isEditing,
    required this.pendingImageFile,
    required this.existingImageUrl,
    required this.pendingLinkUrl,
    required this.onPickImage,
    required this.onAddLink,
    required this.onRemoveImage,
    required this.onRemoveLink,
    required this.onCancelEdit,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isEditing;
  final File? pendingImageFile;
  final String? existingImageUrl;
  final String? pendingLinkUrl;
  final VoidCallback onPickImage;
  final VoidCallback onAddLink;
  final VoidCallback onRemoveImage;
  final VoidCallback onRemoveLink;
  final VoidCallback onCancelEdit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final hasImagePreview =
        pendingImageFile != null || (existingImageUrl?.isNotEmpty ?? false);

    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isEditing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'forum_edit_comment'.tr(),
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: isSending ? null : onCancelEdit,
                        child: Text('cart_cancel'.tr()),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'forum_comment_hint'.tr(),
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              if (hasImagePreview) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: pendingImageFile != null
                          ? Image.file(
                              pendingImageFile!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              existingImageUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(32, 32),
                        ),
                        onPressed: isSending ? null : onRemoveImage,
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (pendingLinkUrl != null && pendingLinkUrl!.isNotEmpty) ...[
                InputChip(
                  avatar: Icon(Icons.link, size: 16, color: Colors.blue.shade700),
                  label: Text(
                    pendingLinkUrl!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: isSending ? null : onRemoveLink,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  IconButton(
                    tooltip: 'forum_add_image'.tr(),
                    onPressed: isSending ? null : onPickImage,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    tooltip: 'forum_add_link'.tr(),
                    onPressed: isSending ? null : onAddLink,
                    icon: const Icon(Icons.link),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: isSending ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    icon: _isSendingIcon(isSending),
                    label: Text(
                      isEditing
                          ? 'forum_comment_save'.tr()
                          : 'forum_post_comment'.tr(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _isSendingIcon(bool sending) {
    if (!sending) {
      return Icon(isEditing ? Icons.save : Icons.send, size: 18);
    }
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
