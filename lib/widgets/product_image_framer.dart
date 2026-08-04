import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Okvir za sliku proizvoda — povlačenje i pinch za centriranje fokusa.
class ProductImageFramer extends StatefulWidget {
  const ProductImageFramer({
    super.key,
    required this.frameKey,
    this.imageFile,
    this.networkUrl,
    this.height = 180,
    this.borderRadius = 20,
    this.onChangePhoto,
  });

  final GlobalKey frameKey;
  final File? imageFile;
  final String? networkUrl;
  final double height;
  final double borderRadius;
  final VoidCallback? onChangePhoto;

  static Future<File?> exportFrame(GlobalKey frameKey) async {
    final boundary = frameKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'product_frame_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    final file = File(path);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  @override
  State<ProductImageFramer> createState() => _ProductImageFramerState();
}

class _ProductImageFramerState extends State<ProductImageFramer> {
  final TransformationController _controller = TransformationController();
  Size? _imageSize;
  bool _loadingSize = false;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(covariant ProductImageFramer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageFile?.path != widget.imageFile?.path ||
        oldWidget.networkUrl != widget.networkUrl) {
      _loadImageSize();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    final file = widget.imageFile;
    if (file == null) {
      setState(() => _imageSize = null);
      return;
    }

    setState(() => _loadingSize = true);
    try {
      final size = await _decodeDisplaySize(file);
      if (!mounted) return;
      setState(() {
        _imageSize = size;
        _loadingSize = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerImage());
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSize = false);
    }
  }

  /// Same decode path as [Image.file] — respects EXIF orientation from the camera.
  Future<Size> _decodeDisplaySize(File file) async {
    final completer = Completer<Size>();
    final stream = FileImage(file).resolve(const ImageConfiguration());
    late ImageStreamListener listener;

    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) {
          completer.complete(
            Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ),
          );
        }
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

  void _centerImage() {
    if (_imageSize == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final frameW = box.size.width;
    final frameH = box.size.height;
    final child = _coverChildSize(frameW, frameH, _imageSize!);
    _controller.value = Matrix4.identity()
      ..translate(
        (frameW - child.width) / 2,
        (frameH - child.height) / 2,
      );
  }

  Size _coverChildSize(double frameW, double frameH, Size imageSize) {
    final scale = (frameW / imageSize.width) > (frameH / imageSize.height)
        ? frameW / imageSize.width
        : frameH / imageSize.height;
    return Size(imageSize.width * scale, imageSize.height * scale);
  }

  @override
  Widget build(BuildContext context) {
    final hasLocal = widget.imageFile != null;
    final hasRemote =
        !hasLocal && (widget.networkUrl?.trim().isNotEmpty ?? false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
        ),
        child: hasLocal
            ? _buildLocalFramer()
            : hasRemote
                ? _buildRemotePreview()
                : _buildEmptyPlaceholder(),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onChangePhoto,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 50, color: Colors.green[700]),
            const SizedBox(height: 8),
            Text(
              'add_product_add_image_title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'add_product_add_image_subtitle'.tr(),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemotePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          widget.networkUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
        ),
        if (widget.onChangePhoto != null)
          Positioned(
            top: 8,
            right: 8,
            child: _changePhotoButton(),
          ),
      ],
    );
  }

  Widget _buildLocalFramer() {
    if (_loadingSize || _imageSize == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final frameW = constraints.maxWidth;
        final frameH = constraints.maxHeight;
        final childSize = _coverChildSize(frameW, frameH, _imageSize!);

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: SizedBox(
                width: frameW,
                height: frameH,
                child: RepaintBoundary(
                  key: widget.frameKey,
                  child: ClipRect(
                    child: InteractiveViewer(
                      transformationController: _controller,
                      minScale: 1.0,
                      maxScale: 4.0,
                      panEnabled: true,
                      scaleEnabled: true,
                      clipBehavior: Clip.hardEdge,
                      boundaryMargin: EdgeInsets.zero,
                      child: SizedBox(
                        width: childSize.width,
                        height: childSize.height,
                        child: Image.file(
                          widget.imageFile!,
                          fit: BoxFit.cover,
                          width: childSize.width,
                          height: childSize.height,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'add_product_image_adjust_hint'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.onChangePhoto != null)
              Positioned(
                top: 8,
                right: 8,
                child: _changePhotoButton(),
              ),
          ],
        );
      },
    );
  }

  Widget _changePhotoButton() {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: widget.onChangePhoto,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                'add_product_change_image'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
