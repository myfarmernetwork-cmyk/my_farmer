import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../models/farmer_shop_settings.dart';
import '../../models/company_catalog_item.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../services/currency_service.dart';
import '../../utils/firestore_error_helper.dart';
import '../../utils/production_types.dart';
import '../../widgets/farmer_shop_info_card.dart';
import '../../widgets/firestore_error_panel.dart';
import '../../widgets/follow_farmer_button.dart';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: Text(title ?? 'storefront_products'.tr()),
      ),
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          title: Text('storefront_products'.tr()),
        ),
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
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              title: Text('storefront_products'.tr()),
            ),
            body: const StorefrontProfileLoadingView(),
          );
        }

        if (!sellerSnapshot.hasData || sellerSnapshot.data == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            body: Center(child: Text('storefront_profile_hidden'.tr())),
          );
        }

        late final StorefrontSellerData seller;
        seller = StorefrontSellerData.fromMap(sellerSnapshot.data);

        if (!seller.isPublicProfile) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'storefront_profile_hidden'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final shopSettings = FarmerShopSettings.fromMap(seller.raw);
        final farmerName = seller.name;
        final tabConfig = StorefrontTabConfig.fromSellerData(seller.raw);
        final showCompanyCatalog = tabConfig.canonicalRole == 'pharmacy';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            title: Text(
              farmerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
            ),
          ),
        );
      },
    );
  }
}

class _StorefrontHeaderSection extends StatelessWidget {
  const _StorefrontHeaderSection({
    required this.seller,
    required this.farmerName,
    required this.sellerId,
    required this.shopSettings,
  });

  final StorefrontSellerData seller;
  final String farmerName;
  final String sellerId;
  final FarmerShopSettings shopSettings;

  @override
  Widget build(BuildContext context) {
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
            ),
            const SizedBox(width: 12),
            FollowFarmerButton(
              farmerId: sellerId,
              farmerName: farmerName,
            ),
          ],
        ),
        const SizedBox(height: 12),
        FarmerShopInfoCard(settings: shopSettings, compact: true),
        const SizedBox(height: 16),
        Text(
          'storefront_products'.tr(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
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
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    ),
                  ),
                  if (item.skuCode.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.skuCode,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
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
          backgroundColor: Colors.green.shade50,
          iconColor: Colors.green.shade800,
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
                ),
              ),
              if (seller.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  seller.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
  });

  final double avgRating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text(
              avgRating > 0 ? avgRating.toStringAsFixed(1) : 'N/A',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (reviewCount > 0)
              Text(
                ' ($reviewCount)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
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
          Icon(Icons.storefront_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'storefront_no_products'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
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
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(
          product.isService ? Icons.build : Icons.image_outlined,
          color: Colors.grey.shade500,
        ),
      );
    } else {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(10),
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
              color: Colors.grey.shade100,
              child: Icon(Icons.broken_image, color: Colors.grey.shade500),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: product),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
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
                      ),
                    ),
                    const SizedBox(height: 6),
                    ProductCardPriceText(
                      price: product.price,
                      originalCurrency: product.originalCurrency,
                      unit: product.displayUnit,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
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
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
