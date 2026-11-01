import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/agro_accent_colors.dart';
import '../../models/farmer_shop_settings.dart';
import '../../models/company_catalog_item.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../services/currency_service.dart';
import '../../utils/firestore_error_helper.dart';
import '../../utils/production_types.dart';
import '../../utils/scroll_bottom_padding.dart';
import '../../widgets/farmer_review_prompt.dart';
import '../../widgets/farmer_shop_info_card.dart';
import '../../widgets/firestore_error_panel.dart';
import '../../widgets/follow_farmer_button.dart';
import '../../widgets/navigate_to_farmer_button.dart';
import '../../widgets/product_card.dart';
import '../../widgets/profile_avatar.dart';
import 'product_details_screen.dart';
import 'storefront_layout.dart';
import 'storefront_seller_data.dart';
import 'storefront_tab_config.dart';
import 'widgets/storefront_loading_view.dart';

/// Opens the public seller profile for any [sellerId] from marketplace flows.
void openSellerProfile(BuildContext context, String sellerId) {
  final id = sellerId.trim();
  if (id.isEmpty) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FarmerStorefrontScreen(sellerId: id),
    ),
  );
}

/// Public seller profile — one scroll list, same pattern as seller home screen.
class FarmerStorefrontScreen extends ConsumerStatefulWidget {
  const FarmerStorefrontScreen({super.key, required this.sellerId});

  final String sellerId;

  static const _priceYellow = Color(0xFFFFEB3B);
  static const _unifiedGreen = AgroAccentColors.marketplaceUnifiedGreen;
  static const _chipGreen = AgroAccentColors.marketplaceChipGreen;

  static AppBar _appBar({String? title, List<Widget>? actions}) {
    return AppBar(
      backgroundColor: _unifiedGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: actions,
      title: title == null
          ? null
          : Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
    );
  }

  @override
  ConsumerState<FarmerStorefrontScreen> createState() =>
      _FarmerStorefrontScreenState();
}

class _FarmerStorefrontScreenState extends ConsumerState<FarmerStorefrontScreen> {
  int _reloadToken = 0;

  void _retry() => setState(() => _reloadToken++);

  Scaffold _errorScaffold({
    required Object error,
    String? title,
  }) {
    return Scaffold(
      backgroundColor: FarmerStorefrontScreen._unifiedGreen,
      appBar: FarmerStorefrontScreen._appBar(title: title),
      body: SizedBox.expand(
        child: FirestoreErrorPanel(
          error: error,
          onRetry: _retry,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    if (authAsync.isLoading) {
      return Scaffold(
        backgroundColor: FarmerStorefrontScreen._unifiedGreen,
        appBar: FarmerStorefrontScreen._appBar(title: 'storefront_products'.tr()),
        body: const StorefrontProfileLoadingView(),
      );
    }

    if (authAsync.valueOrNull == null) {
      return _errorScaffold(error: const FirestoreNotSignedInException());
    }

    return _buildStorefrontContent(context);
  }

  Widget _buildStorefrontContent(BuildContext context) {
    final productRepo = ref.watch(productRepositoryProvider);

    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey('seller-${widget.sellerId}-$_reloadToken'),
      future: productRepo.getSellerData(widget.sellerId),
      builder: (context, sellerSnapshot) {
        if (sellerSnapshot.hasError) {
          return _errorScaffold(error: sellerSnapshot.error!);
        }

        if (sellerSnapshot.connectionState == ConnectionState.waiting &&
            !sellerSnapshot.hasData) {
          return Scaffold(
            backgroundColor: FarmerStorefrontScreen._unifiedGreen,
            appBar: FarmerStorefrontScreen._appBar(title: 'storefront_products'.tr()),
            body: const StorefrontProfileLoadingView(),
          );
        }

        if (!sellerSnapshot.hasData || sellerSnapshot.data == null) {
          return Scaffold(
            backgroundColor: FarmerStorefrontScreen._unifiedGreen,
            appBar: FarmerStorefrontScreen._appBar(),
            body: Center(
              child: Text(
                'storefront_profile_hidden'.tr(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
          );
        }

        late final StorefrontSellerData seller;
        seller = StorefrontSellerData.fromMap(sellerSnapshot.data);

        if (!seller.isPublicProfile) {
          return Scaffold(
            backgroundColor: FarmerStorefrontScreen._unifiedGreen,
            appBar: FarmerStorefrontScreen._appBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'storefront_profile_hidden'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ),
          );
        }

        final shopSettings = FarmerShopSettings.fromMap(seller.raw);
        final farmerName = seller.name;
        final tabConfig = StorefrontTabConfig.fromSellerData(seller.raw);
        final isAdmin = ref.watch(adminPremiumBypassProvider);
        final showCompanyCatalog =
            tabConfig.canonicalRole == 'pharmacy' && isAdmin;
        final currentUid = ref.watch(currentAuthUidProvider);
        final canRateFarmer =
            currentUid != null && currentUid.trim() != widget.sellerId.trim();

        return Scaffold(
          backgroundColor: FarmerStorefrontScreen._unifiedGreen,
          appBar: FarmerStorefrontScreen._appBar(
            title: farmerName,
            actions: canRateFarmer
                ? [
                    IconButton(
                      icon: const Icon(Icons.star_outline),
                      tooltip: 'product_rate_farmer'.tr(),
                      onPressed: () => showFarmerReviewPrompt(
                        context,
                        ref,
                        sellerId: widget.sellerId,
                      ),
                    ),
                  ]
                : null,
          ),
          body: _StorefrontScrollBody(
            sellerId: widget.sellerId,
            productRepo: productRepo,
            onRetry: _retry,
            showCompanyCatalog: showCompanyCatalog,
            orderCurrency: shopSettings.orderCurrency,
            header: _StorefrontHeaderSection(
              seller: seller,
              farmerName: farmerName,
              sellerId: widget.sellerId,
              shopSettings: shopSettings,
              canRateFarmer: canRateFarmer,
            ),
          ),
        );
      },
    );
  }
}

class _StorefrontHeaderSection extends ConsumerWidget {
  const _StorefrontHeaderSection({
    required this.seller,
    required this.farmerName,
    required this.sellerId,
    required this.shopSettings,
    required this.canRateFarmer,
  });

  final StorefrontSellerData seller;
  final String farmerName;
  final String sellerId;
  final FarmerShopSettings shopSettings;
  final bool canRateFarmer;

  void _openReview(BuildContext context, WidgetRef ref) {
    showFarmerReviewPrompt(
      context,
      ref,
      sellerId: sellerId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SellerProfileHeader(
          seller: seller,
          farmerName: farmerName,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _RatingChip(
              avgRating: seller.avgRating,
              reviewCount: seller.reviewCount,
              onTap: canRateFarmer ? () => _openReview(context, ref) : null,
            ),
            const SizedBox(width: 12),
            FollowFarmerButton(
              farmerId: sellerId,
              farmerName: farmerName,
              marketplaceStyle: true,
            ),
          ],
        ),
        if (canRateFarmer) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openReview(context, ref),
              icon: const Icon(Icons.star_outline, size: 18),
              label: Text('product_rate_farmer'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FarmerShopInfoCard(
          settings: shopSettings,
          compact: true,
          marketplaceStyle: true,
        ),
        if (NavigateToFarmerButton.canNavigateSeller(
          seller: seller,
          settings: shopSettings,
        )) ...[
          const SizedBox(height: 12),
          NavigateToFarmerButton(
            name: farmerName,
            address: seller.address,
            lat: shopSettings.farmLat,
            lng: shopSettings.farmLng,
            marketplaceStyle: true,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'storefront_products'.tr(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _StorefrontScrollBody extends StatelessWidget {
  const _StorefrontScrollBody({
    required this.sellerId,
    required this.productRepo,
    required this.onRetry,
    required this.header,
    required this.showCompanyCatalog,
    required this.orderCurrency,
  });

  final String sellerId;
  final ProductRepository productRepo;
  final VoidCallback onRetry;
  final Widget header;
  final bool showCompanyCatalog;
  final String orderCurrency;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: header,
          ),
        ),
        StreamBuilder<List<Product>>(
          stream: productRepo.getProductsBySeller(sellerId, buyerView: true),
          builder: (context, productsSnapshot) {
            return _productsSliver(
              context: context,
              snapshot: productsSnapshot,
            );
          },
        ),
        if (showCompanyCatalog)
          StreamBuilder<List<CompanyCatalogItem>>(
            stream: productRepo.getCompanyCatalogBySeller(sellerId),
            builder: (context, catalogSnapshot) {
              return _companyCatalogSliver(
                context: context,
                snapshot: catalogSnapshot,
              );
            },
          ),
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: ScrollBottomPadding.insetFullScreen(context),
          ),
        ),
      ],
    );
  }

  Widget _productsSliver({
    required BuildContext context,
    required AsyncSnapshot<List<Product>> snapshot,
  }) {
    if (snapshot.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: FirestoreErrorPanel(
          error: snapshot.error!,
          onRetry: onRetry,
        ),
      );
    }

    final waiting = snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData;
    if (waiting) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.45,
          child: StorefrontCatalogLoadingView(
            horizontalPadding: StorefrontLayout.horizontalPadding(
              MediaQuery.sizeOf(context).width,
            ),
          ),
        ),
      );
    }

    final products = snapshot.data ?? const <Product>[];
    if (products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _EmptyProductsHint(),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: EdgeInsets.fromLTRB(12, index == 0 ? 8 : 0, 12, 10),
          child: _PublicProductTile(product: products[index]),
        ),
        childCount: products.length,
      ),
    );
  }

  Widget _companyCatalogSliver({
    required BuildContext context,
    required AsyncSnapshot<List<CompanyCatalogItem>> snapshot,
  }) {
    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FirestoreErrorPanel(
            error: snapshot.error!,
            onRetry: onRetry,
            compact: true,
          ),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final items = snapshot.data ?? const <CompanyCatalogItem>[];
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Text(
                'storefront_company_catalog'.tr(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            );
          }
          final item = items[index - 1];
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _CompanyCatalogTile(
              item: item,
              orderCurrency: orderCurrency,
            ),
          );
        },
        childCount: items.length + 1,
      ),
    );
  }
}

class _CompanyCatalogTile extends ConsumerWidget {
  const _CompanyCatalogTile({
    required this.item,
    required this.orderCurrency,
  });

  final CompanyCatalogItem item;
  final String orderCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = CurrencyService.normalizeCode(
      orderCurrency.isNotEmpty ? orderCurrency : CurrencyService.bam,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: FarmerStorefrontScreen._chipGreen,
        borderRadius: BorderRadius.circular(
          AgroAccentColors.marketplaceCornerRadius,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  if (item.skuCode.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.skuCode,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ProductCardPriceText(
              price: item.price,
              originalCurrency: currency,
              unit: item.unit,
              style: const TextStyle(
                color: FarmerStorefrontScreen._priceYellow,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerProfileHeader extends StatelessWidget {
  const _SellerProfileHeader({
    required this.seller,
    required this.farmerName,
  });

  final StorefrontSellerData seller;
  final String farmerName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileAvatar(
          imageUrl: seller.profileImageUrl,
          radius: 32,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
          iconColor: Colors.white.withValues(alpha: 0.96),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                farmerName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (seller.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  seller.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.avgRating,
    required this.reviewCount,
    this.onTap,
  });

  final double avgRating;
  final int reviewCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FarmerStorefrontScreen._chipGreen,
        borderRadius: BorderRadius.circular(
          AgroAccentColors.marketplaceCornerRadius,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star,
            color: FarmerStorefrontScreen._priceYellow,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            avgRating > 0 ? avgRating.toStringAsFixed(1) : 'N/A',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (reviewCount > 0)
            Text(
              ' ($reviewCount)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );

    return Flexible(
      child: onTap == null
          ? chip
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(
                  AgroAccentColors.marketplaceCornerRadius,
                ),
                child: chip,
              ),
            ),
    );
  }
}

class _EmptyProductsHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 56,
            color: Colors.white.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 12),
          Text(
            'storefront_no_products'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicProductTile extends ConsumerWidget {
  const _PublicProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const imageSize = 64.0;
    final productionLabel = product.isService
        ? 'seller_service_label'.tr()
        : ProductionTypes.label(
            ProductionTypes.normalize(product.productionType),
          );

    Widget leading;
    if (product.imageUrl.trim().isEmpty) {
      leading = Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          product.isService ? Icons.build : Icons.image_outlined,
          color: Colors.white.withValues(alpha: 0.88),
        ),
      );
    } else {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ProductCardImage(
          isUnavailable: product.isUnavailable,
          child: Image.network(
            product.imageUrl,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: imageSize,
              height: imageSize,
              color: Colors.white.withValues(alpha: 0.18),
              child: Icon(
                Icons.broken_image,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: FarmerStorefrontScreen._chipGreen,
      borderRadius: BorderRadius.circular(
        AgroAccentColors.marketplaceCornerRadius,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(
          AgroAccentColors.marketplaceCornerRadius,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: product),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: leading,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ProductCardPriceText(
                        price: product.price,
                        originalCurrency: product.originalCurrency,
                        unit: product.displayUnit,
                        style: const TextStyle(
                          color: FarmerStorefrontScreen._priceYellow,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        productionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
