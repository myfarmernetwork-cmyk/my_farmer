import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

/// Instagram/Facebook-style feed image bounds (width / height).
abstract final class CommunityImageLayout {
  /// Portrait limit — 4:5.
  static const minAspectRatio = 4 / 5;

  /// Landscape limit — ~1.91:1.
  static const maxAspectRatio = 1.91;

  /// Default while real dimensions load.
  static const defaultAspectRatio = 1.0;

  static double clampFeedAspectRatio(double width, double height) {
    if (width <= 0 || height <= 0) return defaultAspectRatio;
    return (width / height).clamp(minAspectRatio, maxAspectRatio);
  }

  static double? clampStoredAspectRatio(double? stored) {
    if (stored == null || stored <= 0 || !stored.isFinite) return null;
    return stored.clamp(minAspectRatio, maxAspectRatio);
  }

  static Future<double?> readAspectRatioFromFile(File file) async {
    try {
      final size = await _decodeImageSize(FileImage(file));
      return clampFeedAspectRatio(size.width, size.height);
    } catch (_) {
      return null;
    }
  }

  static Future<double?> readAspectRatioFromUrl(String url) async {
    try {
      final size = await _decodeImageSize(NetworkImage(url));
      return clampFeedAspectRatio(size.width, size.height);
    } catch (_) {
      return null;
    }
  }

  static Future<Size> _decodeImageSize(ImageProvider provider) {
    final completer = Completer<Size>();
    final stream = provider.resolve(const ImageConfiguration());
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
}
