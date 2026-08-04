import 'package:flutter/material.dart';

import '../../../widgets/firestore_error_panel.dart';
import '../../../widgets/shimmer_box.dart';
import '../storefront_layout.dart';

/// Full-screen error state — replaces empty gray blocks on load failure.
class StorefrontErrorView extends StatelessWidget {
  const StorefrontErrorView({
    super.key,
    required this.error,
    this.onRetry,
  });

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox.expand(
        child: FirestoreErrorPanel(
          error: error,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

/// Full-screen skeleton while seller profile future is loading.
class StorefrontProfileLoadingView extends StatelessWidget {
  const StorefrontProfileLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = StorefrontLayout.horizontalPadding(constraints.maxWidth);

        return ColoredBox(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderSkeleton(width: constraints.maxWidth),
              Padding(
                padding: EdgeInsets.fromLTRB(padding, 12, padding, 10),
                child: Row(
                  children: [
                    ShimmerBox(
                      width: 96,
                      height: 40,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShimmerBox(
                        height: 44,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StorefrontCatalogLoadingView(
                  horizontalPadding: padding,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final green = Colors.green.shade700;

    return Material(
      color: green,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  ShimmerBox(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                    baseColor: Colors.white24,
                    highlightColor: Colors.white38,
                  ),
                  Expanded(
                    child: Center(
                      child: ShimmerBox(
                        width: width * 0.4,
                        height: 16,
                        borderRadius: BorderRadius.circular(8),
                        baseColor: Colors.white24,
                        highlightColor: Colors.white38,
                      ),
                    ),
                  ),
                  ShimmerBox(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                    baseColor: Colors.white24,
                    highlightColor: Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  ShimmerBox(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                    baseColor: Colors.white24,
                    highlightColor: Colors.white38,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: ShimmerBox(
                width: 64,
                height: 64,
                borderRadius: BorderRadius.circular(32),
                baseColor: Colors.white24,
                highlightColor: Colors.white38,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ShimmerBox(
                width: width * 0.5,
                height: 18,
                borderRadius: BorderRadius.circular(8),
                baseColor: Colors.white24,
                highlightColor: Colors.white38,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 4, right: 4),
                        child: ShimmerBox(
                          height: 32,
                          borderRadius: BorderRadius.circular(8),
                          baseColor: Colors.white24,
                          highlightColor: Colors.white38,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Skeleton list while products/services stream is loading.
class StorefrontCatalogLoadingView extends StatelessWidget {
  const StorefrontCatalogLoadingView({
    super.key,
    this.horizontalPadding = 16,
    this.itemCount = 4,
  });

  final double horizontalPadding;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = StorefrontLayout.productImageSize(constraints.maxWidth);

        return ColoredBox(
          color: Colors.white,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 24),
            children: [
              ShimmerBox(
                width: double.infinity,
                height: 120,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < itemCount; i++) ...[
                _ProductRowSkeleton(imageSize: imageSize),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProductRowSkeleton extends StatelessWidget {
  const _ProductRowSkeleton({required this.imageSize});

  final double imageSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(
          width: imageSize,
          height: imageSize,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShimmerBox(
                width: double.infinity,
                height: 16,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 8),
              ShimmerBox(
                width: 120,
                height: 14,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 8),
              ShimmerBox(
                width: 80,
                height: 12,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Skeleton grid while gallery stream is loading.
class StorefrontGalleryLoadingView extends StatelessWidget {
  const StorefrontGalleryLoadingView({
    super.key,
    this.scrollable = true,
    this.width,
  });

  final bool scrollable;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutWidth = width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0);
        final crossAxisCount = StorefrontLayout.galleryCrossAxisCount(layoutWidth);
        const spacing = 6.0;
        const itemCount = 9;

        final tiles = SliverPadding(
          padding: const EdgeInsets.all(spacing),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => ShimmerBox(
                height: 120,
                borderRadius: BorderRadius.circular(8),
              ),
              childCount: itemCount,
            ),
          ),
        );

        if (scrollable) {
          return ColoredBox(
            color: Colors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [tiles],
            ),
          );
        }

        return ColoredBox(
          color: Colors.white,
          child: CustomScrollView(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            slivers: [tiles],
          ),
        );
      },
    );
  }
}
