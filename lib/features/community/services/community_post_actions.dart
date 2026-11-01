import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/community_post.dart';
import '../repositories/community_post_repository.dart';
import '../utils/community_image_layout.dart';
import '../widgets/community_post_composer_sheet.dart';

class CommunityPostActions {
  CommunityPostActions._();

  static Future<void> editPost(
    BuildContext context,
    CommunityPost post,
    CommunityPostRepository repository,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || post.authorId != userId) return;

    File? initialImage;
    if (post.imageUrl.trim().isNotEmpty) {
      try {
        initialImage = await _downloadImageToTemp(post.imageUrl);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('community_image_load_error'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (!context.mounted) return;

    final draft = await showCommunityPostComposer(
      context: context,
      initialImage: initialImage,
      initialDescription: post.description,
      isEditing: true,
    );
    if (draft == null || !context.mounted) return;

    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final oldImageUrl = post.imageUrl.trim();
      final imageAspectRatio =
          await CommunityImageLayout.readAspectRatioFromFile(draft.imageFile);
      final newImageUrl = await repository.uploadPostImage(draft.imageFile);
      await repository.updateOwnPost(
        postId: post.id,
        userId: userId,
        description: draft.description.isNotEmpty
            ? draft.description
            : 'community_no_description'.tr(),
        imageUrl: newImageUrl,
        imageAspectRatio: imageAspectRatio,
      );

      if (newImageUrl != oldImageUrl) {
        await repository.deleteStorageImage(oldImageUrl);
      }

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('community_post_updated'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> deletePostAsAdmin(
    BuildContext context,
    CommunityPost post,
    CommunityPostRepository repository,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('community_admin_delete_title'.tr()),
        content: Text('community_admin_delete_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('community_delete_post'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await repository.deletePostPermanently(
        postId: post.id,
        authorId: post.authorId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('community_post_deleted'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> deletePost(
    BuildContext context,
    CommunityPost post,
    CommunityPostRepository repository,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || post.authorId != userId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('community_delete_confirm_title'.tr()),
        content: Text('community_delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('community_delete_post'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await repository.deleteOwnPost(
        postId: post.id,
        userId: userId,
        imageUrl: post.imageUrl,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('community_post_deleted'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<File> _downloadImageToTemp(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('download_failed');
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'community_edit_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final file = File(path);
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }
}
