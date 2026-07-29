import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../models/screen_guide_step.dart';
import '../../providers/auth_provider.dart';
import '../../utils/quantity_helper.dart';
import '../../utils/upcoming_product_helper.dart';
import '../../widgets/farmer_helper_button.dart';
import '../../widgets/farmer_weather_banner.dart';
import '../../widgets/product_price_text.dart';
import '../../widgets/product_sold_out_overlay.dart';
import '../../widgets/seller_product_availability_switch.dart';
import 'add_product_screen.dart';
import 'manage_harvest_screen.dart';

class MyProductsScreen extends ConsumerStatefulWidget {
  const MyProductsScreen({super.key});

  @override
  ConsumerState<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends ConsumerState<MyProductsScreen> {
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

  Widget _topBanner({required bool isCompany}) {
    if (isCompany) return const SizedBox.shrink();
    return FarmerWeatherBanner(guideKey: _guideWeatherKey);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final roleAsync = ref.watch(firestoreUserRoleProvider);
    final isCompany =
        UpcomingProductHelper.isCompanyRole(roleAsync.valueOrNull);

    return Scaffold(
      appBar: AppBar(
        title: Text('nav_my_products'.tr()),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          FarmerHelperIconButton(guideSteps: _guideStepsForRole(isCompany)),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topBanner(isCompany: isCompany),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('sellerId', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return KeyedSubtree(
                    key: _guideListKey,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('products_empty'.tr())),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final product = Product.fromFirestore(docs[index]);
                    final card = _FarmerProductCard(product: product);

                    if (index == 0) {
                      return KeyedSubtree(key: _guideListKey, child: card);
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
}

class _FarmerProductCard extends ConsumerWidget {
  const _FarmerProductCard({required this.product});

  final Product product;

  bool get _isHarvestManaged =>
      product.isUpcoming || product.requiresFinalPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockLabel = QuantityHelper.formatWithUnit(
      product.stock,
      product.displayUnit,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.requiresFinalPhoto) _PulsingHarvestAlert(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image, size: 56),
                        )
                      : const Icon(Icons.image, size: 56),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ProductPriceText(
                        price: product.price,
                        originalCurrency: product.originalCurrency,
                        unit: product.displayUnit,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'product_available_stock'.tr(
                          namedArgs: {'quantity': stockLabel},
                        ),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (product.isUnavailable) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            productSoldOutBadgeText(context),
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                      if (product.isHarvestCountdownActive) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            product.isDeliveryUpcoming
                                ? 'product_upcoming_delivery_badge'.tr()
                                : 'product_upcoming_badge'.tr(),
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                      if (product.requiresFinalPhoto) ...[
                        const SizedBox(height: 6),
                        Text(
                          'harvest_awaiting_final_photo_short'.tr(),
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'common_edit'.tr(),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddProductScreen(productToEdit: product),
                    ),
                  ),
                ),
                SellerProductAvailabilitySwitch(product: product),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection('products')
                        .doc(product.id)
                        .delete();
                  },
                ),
              ],
            ),
            if (_isHarvestManaged) ...[
              const Divider(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManageHarvestScreen(product: product),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: product.requiresFinalPhoto
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.agriculture),
                  label: Text('harvest_manage_action'.tr()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PulsingHarvestAlert extends StatefulWidget {
  @override
  State<_PulsingHarvestAlert> createState() => _PulsingHarvestAlertState();
}

class _PulsingHarvestAlertState extends State<_PulsingHarvestAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1).animate(_controller),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'harvest_final_photo_alert'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
