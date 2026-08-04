import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/medical_history_entry.dart';

Future<void> openMedicalAttachment(
  BuildContext context,
  MedicalAttachment attachment,
) async {
  final url = attachment.url.trim();
  if (url.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('animals_attachment_unavailable'.tr())),
      );
    }
    return;
  }

  if (attachment.type == 'pdf') {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('animals_attachment_open_failed'.tr())),
      );
    }
    return;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Text(
              attachment.name.isEmpty
                  ? 'animals_add_image'.tr()
                  : attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          Flexible(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('animals_attachment_open_failed'.tr()),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> openPendingMedicalFile(BuildContext context, File file) async {
  final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
  if (name.endsWith('.pdf')) {
    final uri = Uri.file(file.path);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('animals_attachment_open_failed'.tr())),
      );
    }
    return;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Text(
              file.path.split(Platform.pathSeparator).last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          Flexible(
            child: InteractiveViewer(
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    ),
  );
}

class MedicalAttachmentListTile extends StatelessWidget {
  const MedicalAttachmentListTile({
    super.key,
    required this.attachment,
  });

  final MedicalAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final label = attachment.name.isEmpty ? attachment.url : attachment.name;

    return InkWell(
      onTap: () => openMedicalAttachment(context, attachment),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              attachment.type == 'pdf'
                  ? Icons.picture_as_pdf
                  : Icons.image_outlined,
              size: 20,
              color: Colors.green[700],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
