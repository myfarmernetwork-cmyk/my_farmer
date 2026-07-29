import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_badges_provider.dart';
import '../../utils/production_types.dart';
import '../../utils/upcoming_product_helper.dart';
import '../../models/screen_guide_step.dart';
import '../../widgets/farmer_helper_button.dart';
import '../../widgets/farmer_weather_banner.dart';
import '../../widgets/company_catalog_guide.dart';
import '../../widgets/seller_product_availability_switch.dart';
import '../../widgets/product_price_text.dart';
import '../farmer/farmer_chat_list_screen.dart';
import 'add_product_screen.dart';
import 'company_catalog_screen.dart';
import 'farmer_orders_screen.dart';

class FarmerHomeScreen extends ConsumerStatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  ConsumerState<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends ConsumerState<FarmerHomeScreen> {
  final GlobalKey _guideWeatherKey = GlobalKey();
  final GlobalKey _guideListKey = GlobalKey();
  final GlobalKey _guideFabKey = GlobalKey();

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
      final localeTag = context.locale.toLanguageTag();
      return CompanyCatalogQuickHelpBanner(
        key: ValueKey('company_catalog_banner_$localeTag'),
      );
    }
    return FarmerWeatherBanner(
      guideKey: _guideWeatherKey,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      checkAlertsOnPeriodicRefresh: true,
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
    final user = FirebaseAuth.instance.currentUser;
    final badges = ref.watch(navigationBadgesProvider);
    final roleAsync = ref.watch(firestoreUserRoleProvider);
    final isCompany =
        UpcomingProductHelper.isCompanyRole(roleAsync.valueOrNull);

    Widget badgeIcon(IconData icon, int count) {
      if (count <= 0) return Icon(icon);
      return Badge(
        label: Text('$count'),
        backgroundColor: Colors.red,
        child: Icon(icon),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('nav_my_products'.tr()),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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
          IconButton(
            icon: badgeIcon(Icons.chat_bubble_outline, badges.unreadMessages),
            tooltip: 'seller_messages_tooltip'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FarmerChatListScreen(),
              ),
            ),
          ),
          IconButton(
            icon: badgeIcon(Icons.assignment_outlined, badges.newOrders),
            tooltip: 'seller_orders_tooltip'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FarmerOrdersScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topBanner(context: context, isCompany: isCompany),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('sellerId', isEqualTo: user?.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = snapshot.hasData
                    ? snapshot.data!.docs
                        .map((doc) => Product.fromFirestore(doc))
                        .toList()
                    : <Product>[];

                if (products.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _productListAnchor(
                        child: Column(
                          children: [
                            const SizedBox(height: 48),
                            Icon(Icons.storefront_outlined,
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'seller_no_products'.tr(),
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'seller_no_products_hint'.tr(),
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final card = Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      ProductPriceText(
                        price: product.price,
                        originalCurrency: product.originalCurrency,
                        unit: product.displayUnit,
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        product.isService
                            ? 'seller_service_label'.tr()
                            : ProductionTypes.label(
                                ProductionTypes.normalize(
                                  product.productionType,
                                ),
                              ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SellerProductAvailabilitySwitch(product: product),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        tooltip: 'common_edit'.tr(),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddProductScreen(
                              productToEdit: product,
                            ),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _confirmDelete(context, product.id);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'animals_delete'.tr(),
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                    );

                    if (index == 0) {
                      return _productListAnchor(child: card);
                    }
                    return card;
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: _guideFabKey,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
        },
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add, color: Colors.white),
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
