import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/forum_category.dart';
import '../repositories/forum_repository.dart';
import 'forum_topic_detail_screen.dart';
import '../../../widgets/farmer_help_widgets.dart';

class ForumCreateTopicScreen extends StatefulWidget {
  const ForumCreateTopicScreen({
    super.key,
    required this.category,
  });

  final ForumCategory category;

  @override
  State<ForumCreateTopicScreen> createState() => _ForumCreateTopicScreenState();
}

class _ForumCreateTopicScreenState extends State<ForumCreateTopicScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final ForumRepository _repository = ForumRepository();

  File? _imageFile;
  bool _isPublishing = false;

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
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

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
      final authorName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'forum_anonymous'.tr();

      final topicId = await _repository.createTopic(
        title: title,
        body: body,
        category: widget.category,
        authorId: user.uid,
        authorName: authorName,
        imageUrl: imageUrl,
      );

      if (!mounted) return;
      Navigator.pop(context);
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
        title: Text('forum_new_topic'.tr()),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
              maxLines: 8,
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
            ],
            OutlinedButton.icon(
              onPressed: _isPublishing ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text('forum_add_image'.tr()),
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
                  : Text(farmerGuideTr(context, 'forum_publish_topic')),
            ),
          ],
        ),
      ),
    );
  }
}
