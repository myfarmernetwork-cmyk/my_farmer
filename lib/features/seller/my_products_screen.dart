import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../models/screen_guide_step.dart';
import '../../providers/auth_provider.dart';
import '../../theme/agro_accent_colors.dart';
import '../../utils/upcoming_product_helper.dart';
import '../../utils/scroll_bottom_padding.dart';
import '../../widgets/farmer_helper_button.dart';
import '../../widgets/agro_glass_chrome.dart';
import '../../widgets/farmer_weather_banner.dart';
import '../../widgets/seller_product_list_card.dart';
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
        .snapshots();
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

  Widget _topBanner({required bool isCompany}) {
    if (isCompany) return const SizedBox.shrink();
    return FarmerWeatherBanner(guideKey: _guideWeatherKey);
  }

  Future<void> _confirmDelete(BuildContext context, String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('seller_delete_product'.tr()),
        content: Text('seller_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cart_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('animals_delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await FirebaseFirestore.instance.collection('products').doc(productId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(firestoreUserRoleProvider);
    final isCompany =
        UpcomingProductHelper.isCompanyRole(roleAsync.valueOrNull);

    return Scaffold(
      backgroundColor: AgroAccentColors.marketplaceUnifiedGreen,
      appBar: AgroGlassAppBar(
        unifiedMarketplaceHeader: true,
        title: Text('nav_my_products'.tr()),
        actions: [
          FarmerHelperIconButton(guideSteps: _guideStepsForRole(isCompany)),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AgroAccentColors.marketplaceUnifiedBackgroundGradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBanner(isCompany: isCompany),
            Expanded(
              child: _productsStream == null
                  ? Center(
                      child: Text(
                        'products_empty'.tr(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _productsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AgroAccentColors.marketplaceChipGreen,
                            ),
                          );
                        }

                        if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty) {
                          return KeyedSubtree(
                            key: _guideListKey,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'products_empty'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        return ListView.builder(
                          padding: ScrollBottomPadding.list(
                            context,
                            base: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            mainTab: true,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final product =
                                Product.fromFirestore(docs[index]);
                            final card = _ProductListEntry(
                              product: product,
                              onEdit: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddProductScreen(
                                    productToEdit: product,
                                  ),
                                ),
                              ),
                              onDelete: () =>
                                  _confirmDelete(context, product.id),
                            );

                            if (index == 0) {
                              return KeyedSubtree(
                                key: _guideListKey,
                                child: card,
                              );
                            }
                            return card;
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
}

class _ProductListEntry extends StatelessWidget {
  const _ProductListEntry({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  bool get _isHarvestManaged =>
      product.isUpcoming || product.requiresFinalPhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (product.requiresFinalPhoto) const _PulsingHarvestAlert(),
        SellerProductListCard(
          product: product,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
        if (_isHarvestManaged) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManageHarvestScreen(product: product),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: product.requiresFinalPhoto
                    ? Colors.red.shade700
                    : AgroAccentColors.marketplaceChipGreen,
                foregroundColor: product.requiresFinalPhoto
                    ? Colors.white
                    : const Color(0xFFFFEB3B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AgroAccentColors.marketplacePillRadius,
                  ),
                ),
              ),
              icon: const Icon(Icons.agriculture),
              label: Text('harvest_manage_action'.tr()),
            ),
          ),
          const SizedBox(height: 2),
        ],
      ],
    );
  }
}

class _PulsingHarvestAlert extends StatefulWidget {
  const _PulsingHarvestAlert();

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
