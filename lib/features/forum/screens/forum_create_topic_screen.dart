import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/forum_category.dart';
import '../models/forum_topic.dart';
import '../repositories/forum_repository.dart';
import '../utils/forum_author_name.dart';
import 'forum_topic_detail_screen.dart';
import '../../../widgets/farmer_help_widgets.dart';

class ForumCreateTopicScreen extends StatefulWidget {
  const ForumCreateTopicScreen({
    super.key,
    required this.category,
    this.editingTopic,
  });

  final ForumCategory category;
  final ForumTopic? editingTopic;

  bool get isEditing => editingTopic != null;

  @override
  State<ForumCreateTopicScreen> createState() => _ForumCreateTopicScreenState();
}

class _ForumCreateTopicScreenState extends State<ForumCreateTopicScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final ForumRepository _repository = ForumRepository();

  File? _imageFile;
  String? _existingImageUrl;
  String? _linkUrl;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    final topic = widget.editingTopic;
    if (topic != null) {
      _titleController.text = topic.title;
      _bodyController.text = topic.body;
      _existingImageUrl = topic.imageUrl;
      _linkUrl = topic.linkUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _existingImageUrl = null;
      });
    }
  }

  Future<String?> _promptLink() async {
    final controller = TextEditingController(text: _linkUrl ?? '');
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
      setState(() => _linkUrl = null);
      return;
    }
    setState(() => _linkUrl = _normalizeLink(raw));
  }

  String _normalizeLink(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _existingImageUrl;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    final path =
        'forum_topics/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final snapshot = await FirebaseStorage.instance.ref(path).putFile(
          _imageFile!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
    return snapshot.ref.getDownloadURL();
  }

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('forum_topic_required'.tr())),
      );
      return;
    }
    if (user == null) return;

    setState(() => _isPublishing = true);
    try {
      final imageUrl = await _uploadImage();
      final authorName = ForumAuthorName.label(
        await ForumAuthorName.forCurrentUser(),
        'forum_anonymous'.tr(),
      );

      if (widget.isEditing) {
        await _repository.updateTopic(
          topicId: widget.editingTopic!.id,
          title: title,
          body: body,
          imageUrl: imageUrl,
          linkUrl: _linkUrl,
          clearImage:
              imageUrl == null && _imageFile == null && _existingImageUrl == null,
          clearLink: _linkUrl == null || _linkUrl!.isEmpty,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      final topicId = await _repository.createTopic(
        title: title,
        body: body,
        category: widget.category,
        authorId: user.uid,
        authorName: authorName,
        imageUrl: imageUrl,
        linkUrl: _linkUrl,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForumTopicDetailScreen(topicId: topicId),
        ),
      );
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
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'forum_edit_topic'.tr()
              : 'forum_new_topic'.tr(),
        ),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'forum_topic_title'.tr(),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: InputDecoration(
                labelText: 'forum_topic_body'.tr(),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 6,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            if (_imageFile != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _imageFile!,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
            ] else if (_existingImageUrl != null &&
                _existingImageUrl!.isNotEmpty) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _existingImageUrl!,
                      height: 180,
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
                      ),
                      onPressed: _isPublishing
                          ? null
                          : () => setState(() {
                                _existingImageUrl = null;
                                _imageFile = null;
                              }),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_linkUrl != null && _linkUrl!.isNotEmpty) ...[
              InputChip(
                avatar: Icon(Icons.link, size: 16, color: Colors.blue.shade700),
                label: Text(
                  _linkUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onDeleted: _isPublishing
                    ? null
                    : () => setState(() => _linkUrl = null),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isPublishing ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text('forum_add_image'.tr()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isPublishing ? null : _addLink,
                    icon: const Icon(Icons.link),
                    label: Text('forum_add_link'.tr()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isPublishing ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isPublishing
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.isEditing
                          ? 'forum_comment_save'.tr()
                          : farmerGuideTr(context, 'forum_publish_topic'),
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
