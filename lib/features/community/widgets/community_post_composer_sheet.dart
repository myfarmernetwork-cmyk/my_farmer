import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'community_gallery_image.dart';
import '../../../theme/agro_accent_colors.dart';
import '../../../widgets/agro_glass_chrome.dart';

class CommunityPostDraft {
  const CommunityPostDraft({
    required this.imageFile,
    required this.description,
  });

  final File imageFile;
  final String description;
}

Future<CommunityPostDraft?> showCommunityPostComposer({
  required BuildContext context,
  File? initialImage,
  String initialDescription = '',
  bool isEditing = false,
}) {
  return showModalBottomSheet<CommunityPostDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    builder: (ctx) => _CommunityPostComposerSheet(
      initialImage: initialImage,
      initialDescription: initialDescription,
      isEditing: isEditing,
    ),
  );
}

class _CommunityPostComposerSheet extends StatefulWidget {
  const _CommunityPostComposerSheet({
    this.initialImage,
    this.initialDescription = '',
    this.isEditing = false,
  });

  final File? initialImage;
  final String initialDescription;
  final bool isEditing;

  @override
  State<_CommunityPostComposerSheet> createState() =>
      _CommunityPostComposerSheetState();
}

class _CommunityPostComposerSheetState extends State<_CommunityPostComposerSheet> {
  static const _chipGreen = AgroAccentColors.marketplaceChipGreen;
  static const _priceYellow = Color(0xFFFFEB3B);

  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.initialImage;
    _descriptionController.text = widget.initialDescription;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _changePhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => _imageFile = File(picked.path));
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text('animals_photo_camera'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _changePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('animals_photo_gallery'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _changePhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publish() async {
    if (_publishing || _imageFile == null) return;
    setState(() => _publishing = true);

    try {
      if (!mounted) return;

      Navigator.pop(
        context,
        CommunityPostDraft(
          imageFile: _imageFile!,
          description: _descriptionController.text.trim(),
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Icon(Icons.landscape, color: _chipGreen, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'community_compose_title'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _chipGreen,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _publishing
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CommunityComposeImagePreview(
                        imageFile: _imageFile,
                        onChangePhoto: _showPhotoSourcePicker,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'community_add_description'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _chipGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        style: marketplaceFormFieldTextStyle,
                        decoration: marketplaceFormInputDecoration(
                          hintText: 'community_description_hint'.tr(),
                        ),
                        maxLines: 4,
                        minLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
                    ],
                  ),
                ),
              ),
              Material(
                elevation: 8,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _publishing
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _chipGreen,
                            side: BorderSide(
                              color: _chipGreen.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text('cart_cancel'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _publishing || _imageFile == null
                              ? null
                              : _publish,
                          style: FilledButton.styleFrom(
                            backgroundColor: _chipGreen,
                            foregroundColor: _priceYellow,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AgroAccentColors.marketplacePillRadius,
                              ),
                            ),
                          ),
                          icon: _publishing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _priceYellow,
                                  ),
                                )
                              : const Icon(Icons.publish_rounded),
                          label: Text(
                            widget.isEditing
                                ? 'community_save'.tr()
                                : 'community_publish'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
