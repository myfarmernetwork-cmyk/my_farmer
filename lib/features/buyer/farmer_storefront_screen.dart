import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../repositories/product_repository.dart';
import '../../models/premium_access.dart';
import '../../models/product.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/follow_farmer_button.dart';
import '../../widgets/farmer_shop_info_card.dart';
import '../../widgets/product_price_text.dart';
import '../../widgets/translated_text.dart';
import '../../models/farmer_shop_settings.dart';
import '../chat/chat_screen.dart';
import '../community/widgets/user_community_gallery_grid.dart';

class FarmerStorefrontScreen extends ConsumerStatefulWidget {
  final String sellerId;
  const FarmerStorefrontScreen({super.key, required this.sellerId});

  @override
  ConsumerState<FarmerStorefrontScreen> createState() =>
      _FarmerStorefrontScreenState();
}

class _FarmerStorefrontScreenState
    extends ConsumerState<FarmerStorefrontScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _showServicesTab = false;
  int _tabCount = 2;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initTabs(String? role) {
    final isHobby = role == 'hobby_farmer';
    final isPro = role == 'professional_farmer' ||
        role == 'farmer' ||
        role == 'services';
    final showServices = !isHobby && isPro;
    final tabCount = (showServices ? 2 : 1) + 1;

    if (_showServicesTab == showServices &&
        _tabCount == tabCount &&
        _tabController != null) {
      return;
    }

    _tabController?.dispose();
    _showServicesTab = showServices;
    _tabCount = tabCount;
    _tabController = TabController(
      length: tabCount,
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    final productRepo = ref.read(productRepositoryProvider);

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>?>(
        future: productRepo.getSellerData(widget.sellerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('storefront_profile_hidden'.tr()));
          }

          final farmer = snapshot.data!;
          final role = farmer['role'] as String?;
          final isPublic = farmer['isPublicProfile'] as bool? ?? true;
          if (!isPublic) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'storefront_profile_hidden'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          _initTabs(role);
          final shopSettings = FarmerShopSettings.fromMap(farmer);
          final avgRating = (farmer['avgRating'] as num?)?.toDouble() ?? 0.0;
          final reviewCount = farmer['reviewCount'] as int? ?? 0;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline,
                        color: Colors.white),
                    onPressed: () => PremiumGate.run(
                      context,
                      ref,
                      feature: PremiumFeature.chat,
                      onUnlocked: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            receiverId: widget.sellerId,
                            receiverName: farmer['name'] ?? 'Farmer',
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: () => _showFarmerDetails(context, farmer),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    farmer['name'] ?? 'Farmer',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  background: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          backgroundImage: farmer['profileImageUrl'] != null
                              ? NetworkImage(farmer['profileImageUrl'])
                              : null,
                          child: farmer['profileImageUrl'] == null
                              ? const Icon(Icons.person,
                                  size: 40, color: Colors.green)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                bottom: _tabController != null
                    ? TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        indicatorColor: Colors.white,
                        tabs: [
                          Tab(text: 'storefront_products'.tr()),
                          if (_showServicesTab)
                            Tab(text: 'storefront_services'.tr()),
                          Tab(text: 'profile_tab_gallery'.tr()),
                        ],
                      )
                    : null,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              avgRating > 0
                                  ? avgRating.toStringAsFixed(1)
                                  : 'N/A',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if (reviewCount > 0)
                              Text(
                                ' ($reviewCount)',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FollowFarmerButton(
                        farmerId: widget.sellerId,
                        farmerName: farmer['name'] ?? 'Farmer',
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FarmerShopInfoCard(settings: shopSettings),
                ),
              ),
            ],
            body: _tabController != null
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _ProductList(
                        sellerId: widget.sellerId,
                        servicesOnly: false,
                      ),
                      if (_showServicesTab)
                        _ProductList(
                          sellerId: widget.sellerId,
                          servicesOnly: true,
                        ),
                      UserCommunityGalleryGrid(userId: widget.sellerId),
                    ],
                  )
                : _ProductList(
                    sellerId: widget.sellerId,
                    servicesOnly: false,
                  ),
          );
        },
      ),
    );
  }

  void _showFarmerDetails(
      BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['name'] ?? 'Farmer',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Text('${'address'.tr()}: ${data['address'] ?? '-'}'),
            Text('${'phone'.tr()}: ${data['phone'] ?? '-'}'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ProductList extends ConsumerWidget {
  final String sellerId;
  final bool servicesOnly;

  const _ProductList({
    required this.sellerId,
    required this.servicesOnly,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs
            .map((d) => Product.fromFirestore(d))
            .where((p) => p.isService == servicesOnly && p.isVisibleToBuyers)
            .toList();

        if (items.isEmpty) {
          return Center(
            child: Text(
              servicesOnly
                  ? 'storefront_no_services'.tr()
                  : 'storefront_no_products'.tr(),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final prod = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  prod.isService ? Icons.build : Icons.eco,
                  color: Colors.green,
                ),
                title: TranslatedText(
                  prod.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: ProductPriceText(
                  price: prod.price,
                  unit: prod.displayUnit,
                  style: TextStyle(color: Colors.green[700]),
                ),
                trailing: Text(
                  prod.productionType,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
