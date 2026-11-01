import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../utils/community_image_layout.dart';

/// Pregled slike pri objavi — isti omjer kao u feedu, cijela slika vidljiva.
class CommunityComposeImagePreview extends StatefulWidget {
  const CommunityComposeImagePreview({
    super.key,
    required this.imageFile,
    this.onChangePhoto,
  });

  final File? imageFile;
  final VoidCallback? onChangePhoto;

  @override
  State<CommunityComposeImagePreview> createState() =>
      _CommunityComposeImagePreviewState();
}

class _CommunityComposeImagePreviewState
    extends State<CommunityComposeImagePreview> {
  double? _aspectRatio;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAspectRatio();
  }

  @override
  void didUpdateWidget(covariant CommunityComposeImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageFile?.path != widget.imageFile?.path) {
      _loadAspectRatio();
    }
  }

  Future<void> _loadAspectRatio() async {
    final file = widget.imageFile;
    if (file == null) {
      setState(() => _aspectRatio = null);
      return;
    }

    setState(() => _loading = true);
    final ratio = await CommunityImageLayout.readAspectRatioFromFile(file);
    if (!mounted) return;
    setState(() {
      _aspectRatio = ratio ?? CommunityImageLayout.defaultAspectRatio;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.imageFile;
    if (file == null) {
      return _EmptyPhotoPicker(onTap: widget.onChangePhoto);
    }

    if (_loading || _aspectRatio == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: _aspectRatio!,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.grey.shade200,
              child: Image.file(
                file,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                gaplessPlayback: true,
              ),
            ),
            if (widget.onChangePhoto != null)
              Positioned(
                top: 8,
                right: 8,
                child: _ChangePhotoChip(onTap: widget.onChangePhoto!),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPhotoPicker extends StatelessWidget {
  const _EmptyPhotoPicker({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withValues(alpha: 0.45)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, size: 50, color: Colors.green[700]),
              const SizedBox(height: 8),
              Text(
                'add_product_add_image_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePhotoChip extends StatelessWidget {
  const _ChangePhotoChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
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

/// Feed slika — puna širina, varijabilna visina, cover + centar.
class CommunityFeedImage extends StatefulWidget {
  const CommunityFeedImage({
    super.key,
    required this.imageUrl,
    this.storedAspectRatio,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String imageUrl;
  final double? storedAspectRatio;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<CommunityFeedImage> createState() => _CommunityFeedImageState();
}

class _CommunityFeedImageState extends State<CommunityFeedImage> {
  static final Map<String, double> _aspectCache = {};

  double? _aspectRatio;
  bool _resolvedFromNetwork = false;

  bool get _hasStoredAspect =>
      CommunityImageLayout.clampStoredAspectRatio(
            widget.storedAspectRatio,
          ) !=
          null;

  bool get _canShowImage =>
      _hasStoredAspect || _resolvedFromNetwork || _aspectCache.containsKey(widget.imageUrl.trim());

  @override
  void initState() {
    super.initState();
    _initAspectRatio();
  }

  @override
  void didUpdateWidget(covariant CommunityFeedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.storedAspectRatio != widget.storedAspectRatio) {
      _initAspectRatio();
    }
  }

  void _initAspectRatio() {
    final stored = CommunityImageLayout.clampStoredAspectRatio(
      widget.storedAspectRatio,
    );
    final url = widget.imageUrl.trim();
    final cached = url.isEmpty ? null : _aspectCache[url];
    _aspectRatio = stored ?? cached;
    _resolvedFromNetwork = stored != null || cached != null;

    if (url.isNotEmpty) {
      _resolveAspectRatio();
    }
  }

  Future<void> _resolveAspectRatio() async {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) return;

    final resolved = await CommunityImageLayout.readAspectRatioFromUrl(url);
    if (!mounted) return;

    if (resolved != null) {
      _aspectCache[url] = resolved;
      setState(() {
        _aspectRatio = resolved;
        _resolvedFromNetwork = true;
      });
      return;
    }

    if (!_canShowImage) {
      setState(() => _resolvedFromNetwork = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.grey.shade200;
    final aspectRatio = _aspectRatio ??
        CommunityImageLayout.clampStoredAspectRatio(widget.storedAspectRatio) ??
        CommunityImageLayout.defaultAspectRatio;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRect(
        child: ColoredBox(
          color: bg,
          child: _canShowImage
              ? Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                  loadingBuilder: widget.loadingBuilder ??
                      (context, child, progress) {
                        if (progress == null) return child;
                        return ColoredBox(
                          color: bg,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color: Colors.green.shade700,
                            ),
                          ),
                        );
                      },
                  errorBuilder: widget.errorBuilder ??
                      (_, __, ___) => ColoredBox(
                            color: bg,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: Colors.grey.shade500,
                                  size: 40,
                                ),
                              ],
                            ),
                          ),
                )
              : Center(
                  child: CircularProgressIndicator(
                    color: Colors.green.shade700,
                    strokeWidth: 2,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Prikaz slike u profil gridu / ostalim manjim pločicama.
class CommunityGalleryImage extends StatelessWidget {
  const CommunityGalleryImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.fit = BoxFit.contain,
    this.backgroundColor,
    this.borderRadius,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String imageUrl;
  final double? height;
  final BoxFit fit;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.grey.shade100;

    Widget image = Image.network(
      imageUrl,
      fit: fit,
      width: double.infinity,
      height: height ?? double.infinity,
      gaplessPlayback: true,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder ??
          (_, __, ___) => ColoredBox(
                color: bg,
                child: Icon(Icons.broken_image, color: Colors.grey.shade500),
              ),
    );

    if (height != null) {
      image = SizedBox(
        width: double.infinity,
        height: height,
        child: image,
      );
    }

    image = ColoredBox(color: bg, child: image);

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

/// Puni pregled slike na klik — cijela slika + pinch zoom.
class CommunityGalleryImagePreview extends StatelessWidget {
  const CommunityGalleryImagePreview({
    super.key,
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.65;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ColoredBox(
        color: Colors.black87,
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (_, __, ___) => SizedBox(
              height: 220,
              child: Center(
                child: Icon(Icons.broken_image, color: Colors.grey.shade400),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
