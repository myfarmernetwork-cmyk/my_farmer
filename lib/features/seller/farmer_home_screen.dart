import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_badges_provider.dart';
import '../../providers/notification_navigation_provider.dart';
import '../../utils/upcoming_product_helper.dart';
import '../../utils/scroll_bottom_padding.dart';
import '../../models/screen_guide_step.dart';
import '../../widgets/agro_glass_chrome.dart';
import '../../widgets/farmer_helper_button.dart';
import '../../widgets/farmer_weather_banner.dart';
import '../../widgets/notification_context_banner.dart';
import '../../widgets/company_catalog_guide.dart';
import '../../theme/agro_accent_colors.dart';
import '../../widgets/seller_product_list_card.dart';
import '../farmer/farmer_chat_list_screen.dart';
import 'add_product_screen.dart';
import 'company_catalog_screen.dart';
import 'farmer_orders_screen.dart';
import '../notifications/notifications_screen.dart';

class FarmerHomeScreen extends ConsumerStatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  ConsumerState<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends ConsumerState<FarmerHomeScreen> {
  final GlobalKey _guideWeatherKey = GlobalKey();
  final GlobalKey _guideListKey = GlobalKey();
  final GlobalKey _guideFabKey = GlobalKey();
  final ScrollController _productScrollController = ScrollController();
  final GlobalKey _highlightProductKey = GlobalKey();
  String? _lastScrolledProductId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _productsStream;

  @override
  void initState() {
    super.initState();
    _bindProductsStream();
  }

  void _bindProductsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      _productsStream = null;
      return;
    }
    _productsStream = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _productScrollController.dispose();
    super.dispose();
  }

  void _scrollToProductIfNeeded(String? productId) {
    if (productId == null || productId.isEmpty) return;
    if (_lastScrolledProductId == productId) return;
    _lastScrolledProductId = productId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _highlightProductKey.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        alignment: 0.2,
        curve: Curves.easeInOut,
      );
    });
  }

  List<ScreenGuideStep> _guideStepsForRole(bool isCompany) => [
        if (!isCompany)
          ScreenGuideStep(
            targetKey: _guideWeatherKey,
            titleKey: 'guide_farmer_weather_title',
            bodyKey: 'guide_farmer_weather_body',
          ),
        ScreenGuideStep(
          targetKey: _guideListKey,
          titleKey: 'guide_farmer_list_title',
          bodyKey: 'guide_farmer_list_body',
        ),
        ScreenGuideStep(
          targetKey: _guideFabKey,
          titleKey: 'guide_farmer_add_title',
          bodyKey: 'guide_farmer_add_body',
        ),
      ];

  Widget _topBanner({
    required BuildContext context,
    required bool isCompany,
  }) {
    if (isCompany) {
      return _companyCatalogBanner(context);
    }
    return FarmerWeatherBanner(
      guideKey: _guideWeatherKey,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      marketplaceSurface: true,
    );
  }

  Widget _companyCatalogBanner(BuildContext context) {
    final localeTag = context.locale.toLanguageTag();
    return CompanyCatalogQuickHelpBanner(
      key: ValueKey('company_catalog_banner_$localeTag'),
    );
  }

  Widget _productListAnchor({required Widget child}) {
    return KeyedSubtree(
      key: _guideListKey,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badges = ref.watch(navigationBadgesProvider);
    final notificationIntent = ref.watch(notificationIntentProvider);
    final highlightProductId = notificationIntent?.target ==
            NotificationTarget.lowStock
        ? notificationIntent?.productId
        : null;
    final roleAsync = ref.watch(firestoreUserRoleProvider);
    final isCompany =
        UpcomingProductHelper.isCompanyRole(roleAsync.valueOrNull);

    return Scaffold(
      backgroundColor: AgroAccentColors.marketplaceUnifiedGreen,
      appBar: AgroGlassAppBar(
        unifiedMarketplaceHeader: true,
        title: Text('nav_my_products'.tr()),
        actions: [
          const NotificationsBellButton(),
          FarmerHelperIconButton(guideSteps: _guideStepsForRole(isCompany)),
          if (isCompany) ...[
            const CompanyCatalogPdfGuideButton(),
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'company_catalog_title'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CompanyCatalogScreen(),
              ),
            ),
          ),
          ],
          AgroHeaderIconButton(
            icon: Icons.chat_bubble_outline,
            badgeCount: badges.unreadMessages,
            tooltip: 'seller_messages_tooltip'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FarmerChatListScreen(),
              ),
            ),
          ),
          AgroHeaderIconButton(
            icon: Icons.assignment_outlined,
            badgeCount: badges.newOrders,
            tooltip: 'seller_orders_tooltip'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FarmerOrdersScreen()),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: AgroAccentColors.marketplaceUnifiedGreen,
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notificationIntent != null &&
              notificationIntent.target != NotificationTarget.orders)
            const NotificationContextBanner(),
          _topBanner(context: context, isCompany: isCompany),
          Expanded(
            child: _productsStream == null
                ? Center(
                    child: Text(
                      'seller_no_products'.tr(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 16,
                      ),
                    ),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _productsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  );
                }

                final products = snapshot.hasData
                    ? snapshot.data!.docs
                        .map((doc) => Product.fromFirestore(doc))
                        .toList()
                    : <Product>[];

                if (products.isEmpty) {
                  return ListView(
                    padding: ScrollBottomPadding.list(
                      context,
                      base: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      mainTab: true,
                    ),
                    children: [
                      _productListAnchor(
                        child: Column(
                          children: [
                            const SizedBox(height: 48),
                            Icon(
                              Icons.storefront_outlined,
                              size: 80,
                              color: AgroAccentColors.marketplaceChipGreen,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'seller_no_products'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withValues(alpha: 0.90),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'seller_no_products_hint'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  controller: _productScrollController,
                  padding: ScrollBottomPadding.list(
                    context,
                    base: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    mainTab: true,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final highlighted =
                        highlightProductId != null && product.id == highlightProductId;
                    if (highlighted) {
                      _scrollToProductIfNeeded(product.id);
                    }
                    final card = SellerProductListCard(
                      product: product,
                      highlighted: highlighted,
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddProductScreen(
                            productToEdit: product,
                          ),
                        ),
                      ),
                      onDelete: () => _confirmDelete(context, product.id),
                    );

                    Widget wrapped = card;
                    if (highlighted) {
                      wrapped = KeyedSubtree(key: _highlightProductKey, child: card);
                    } else if (index == 0) {
                      wrapped = _productListAnchor(child: card);
                    }
                    return wrapped;
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
      floatingActionButtonLocation: ScrollBottomPadding.fabLocationMainTabRaised,
      floatingActionButton: MarketplacePrimaryFab(
        key: _guideFabKey,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String productId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('seller_delete_product'.tr()),
        content: Text('seller_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cart_cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('products')
                  .doc(productId)
                  .delete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'animals_delete'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kompatibilnost sa starijim nazivom ekrana.
typedef SellerHomeScreen = FarmerHomeScreen;
