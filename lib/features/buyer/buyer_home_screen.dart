import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/app_user.dart';
import '../../models/farmer_shop_settings.dart';
import '../../screens/vet_finder_screen.dart';
import '../../services/vet_navigation_service.dart';
import '../../services/vet_proximity_radar_service.dart';
import '../../widgets/vet_profile_sheet.dart';
import '../../models/product.dart';
import '../../models/search_radius.dart';
import '../../services/search_location_service.dart';
import '../../utils/product_categories.dart';
import '../../utils/production_types.dart';
import '../../utils/scroll_bottom_padding.dart';
import '../../repositories/product_repository.dart';
import '../../models/screen_guide_step.dart';
import '../../providers/navigation_badges_provider.dart';
import '../../providers/notification_navigation_provider.dart';
import '../../widgets/notification_context_banner.dart';
import '../../widgets/farmer_helper_button.dart';
import '../../widgets/agro_filter_chip.dart';
import '../../widgets/agro_glass_chrome.dart';
import '../../widgets/marketplace_product_card.dart';
import '../../widgets/marketplace_category_scroll.dart';
import '../../widgets/marketplace_category_tile.dart';
import '../../widgets/marketplace_pagination_bar.dart';
import '../../theme/agro_accent_colors.dart';
import '../farmer/farmer_chat_list_screen.dart';
import '../notifications/notifications_screen.dart';
import 'buyer_orders_screen.dart';
import 'cart_provider.dart';
import 'cart_screen.dart';
import 'farmer_storefront_screen.dart';
import 'product_details_screen.dart';

String marketplaceSearchHint(BuildContext context) => 'search_placeholder'.tr();

class BuyerHomeScreen extends ConsumerStatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  ConsumerState<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends ConsumerState<BuyerHomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final SearchLocationService _searchLocationService = SearchLocationService();
  late final AnimationController _locationRefreshSpin;

  String _searchQuery = '';
  List<VetProfile> _vetSearchResults = [];
  bool _isSearchingVets = false;
  String _selectedCategory = ProductCategories.all;
  String _selectedType = ProductionTypes.all;
  SearchRadius _selectedRadius = SearchRadius.all;

  Position? _buyerPosition;
  bool _isLoadingLocation = false;
  String? _locationMessage;

  static const _sellerRoles = [
    'hobby_farmer',
    'hobbyist_farmer',
    'professional_farmer',
    'pro_farmer',
    'veterinarian',
    'pharmacy',
    'company',
    'farmer',
  ];


  static const _productionFilters = ProductionTypes.filterCodes;
  static const _productsPerPage = 12;

  int _currentPage = 1;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _productsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _hiddenSellersStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _sellerSettingsStream;
  final Set<String> _harvestTransitionRequested = {};

  final GlobalKey _guideSearchKey = GlobalKey();
  final GlobalKey _guideRadiusKey = GlobalKey();
  final GlobalKey _guideCategoriesKey = GlobalKey();
  final GlobalKey _guideTypeKey = GlobalKey();
  final GlobalKey _guideGridKey = GlobalKey();

  List<ScreenGuideStep> get _guideSteps => [
        ScreenGuideStep(
          targetKey: _guideSearchKey,
          titleKey: 'guide_search_title',
          bodyKey: 'guide_search_body',
        ),
        ScreenGuideStep(
          targetKey: _guideRadiusKey,
          titleKey: 'guide_radius_title',
          bodyKey: 'guide_radius_body',
        ),
        ScreenGuideStep(
          targetKey: _guideCategoriesKey,
          titleKey: 'guide_categories_title',
          bodyKey: 'guide_categories_body',
        ),
        ScreenGuideStep(
          targetKey: _guideTypeKey,
          titleKey: 'guide_type_title',
          bodyKey: 'guide_type_body',
        ),
        ScreenGuideStep(
          targetKey: _guideGridKey,
          titleKey: 'guide_grid_title',
          bodyKey: 'guide_grid_body',
        ),
      ];

  @override
  void initState() {
    super.initState();
    _locationRefreshSpin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _bindMarketplaceStreams();
    // GPS samo u pozadini dok je „Alle“ — bez spinnera kod Suchradius.
    if (!_selectedRadius.isAll) {
      _refreshBuyerLocation(showErrors: false);
    } else {
      unawaited(_refreshBuyerLocation(showErrors: false, showSpinner: false));
    }
  }

  void _bindMarketplaceStreams() {
    _productsStream = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _hiddenSellersStream = FirebaseFirestore.instance
        .collection('users')
        .where('isPublicProfile', isEqualTo: false)
        .snapshots();
    _sellerSettingsStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: _sellerRoles)
        .snapshots();
  }

  @override
  void dispose() {
    _locationRefreshSpin.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setLocationLoading(bool loading) {
    if (loading) {
      if (!_locationRefreshSpin.isAnimating) {
        _locationRefreshSpin.repeat();
      }
    } else {
      _locationRefreshSpin.stop();
      _locationRefreshSpin.reset();
    }
  }

  Future<void> _refreshBuyerLocation({
    bool showErrors = true,
    bool showSpinner = true,
  }) async {
    if (showSpinner && mounted) {
      setState(() {
        _isLoadingLocation = true;
        _locationMessage = null;
      });
      _setLocationLoading(true);
    }

    Position? position;
    try {
      position = await _searchLocationService.getBuyerPosition().timeout(
            const Duration(seconds: 20),
            onTimeout: () => null,
          );
    } catch (_) {
      position = null;
    }

    if (!mounted) return;

    setState(() {
      _isLoadingLocation = false;
      _buyerPosition = position;
      if (position == null && !_selectedRadius.isAll) {
        _locationMessage = 'search_location_required'.tr();
      } else if (position != null) {
        _locationMessage = null;
      } else if (showErrors && showSpinner) {
        _locationMessage = 'search_location_optional'.tr();
      }
    });
    _setLocationLoading(false);
  }

  void _onRadiusChanged(SearchRadius radius) {
    setState(() {
      _selectedRadius = radius;
      _currentPage = 1;
      if (!radius.isAll && _buyerPosition == null) {
        _locationMessage = 'search_location_required'.tr();
      } else {
        _locationMessage = null;
      }
    });

    if (!radius.isAll) {
      _refreshBuyerLocation();
    }
  }

  Future<void> _onSearchChanged(String val) async {
    setState(() => _searchQuery = val);

    final query = val.trim();
    if (query.length < 2) {
      if (mounted) setState(() => _vetSearchResults = []);
      return;
    }

    setState(() => _isSearchingVets = true);
    final vets = await ref
        .read(vetProximityRadarServiceProvider)
        .searchVetsByName(query, buyerPosition: _buyerPosition);
    if (mounted) {
      setState(() {
        _vetSearchResults = vets;
        _isSearchingVets = false;
      });
    }
  }

  String _radiusLabel(SearchRadius radius) {
    if (radius.isAll) return 'search_radius_all'.tr();
    return 'search_radius_km'.tr(
      namedArgs: {'km': radius.maxKm!.toStringAsFixed(0)},
    );
  }

  List<Product> _filterProducts(
    List<Product> products,
    Set<String> hiddenSellerIds,
  ) {
    return products.where((p) {
      if (hiddenSellerIds.contains(p.sellerId)) return false;
      if (!p.isVisibleToBuyers) return false;

      final matchesSearch = ProductCategories.matchesSearch(p, _searchQuery);
      final matchesCategory = ProductCategories.matchesMarketplaceFilter(
        filterCode: _selectedCategory,
        productCategoryCode: p.categoryCode,
      );
      final matchesType = _selectedType == ProductionTypes.all ||
          ProductionTypes.normalize(p.productionType) == _selectedType;
      return matchesSearch && matchesCategory && matchesType;
    }).toList();
  }

  Map<String, FarmerShopSettings> _sellerSettingsFromSnapshot(
    QuerySnapshot snapshot,
  ) {
    final map = <String, FarmerShopSettings>{};
    for (final doc in snapshot.docs) {
      map[doc.id] = FarmerShopSettings.fromMap(
        doc.data() as Map<String, dynamic>,
      );
    }
    return map;
  }

  String _sellerEmoji(Product product) {
    if (product.isService) return '🔧';
    return '🌾';
  }

  int _totalPages(int itemCount) {
    if (itemCount <= 0) return 1;
    return (itemCount / _productsPerPage).ceil();
  }

  List<RankedProduct> _pageItems(List<RankedProduct> items, int page) {
    if (items.isEmpty) return const [];
    final totalPages = _totalPages(items.length);
    final safePage = page.clamp(1, totalPages);
    final start = (safePage - 1) * _productsPerPage;
    final end = math.min(start + _productsPerPage, items.length);
    return items.sublist(start, end);
  }

  Widget _buildProductGridCard(RankedProduct entry) {
    final product = entry.product;
    final card = MarketplaceProductCard(
      product: product,
      distanceKm: entry.distanceKm,
      sellerEmoji: _sellerEmoji(product),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: product),
        ),
      ),
      onSellerTap: product.sellerId.trim().isEmpty
          ? null
          : () => openSellerProfile(context, product.sellerId),
    );
    return card;
  }

  Widget _buildSearchHeader() {
    final needsLocation = !_selectedRadius.isAll;
    const pillRadius = AgroAccentColors.marketplacePillRadius;
    const pillHeight = AgroAccentColors.marketplaceWidePillHeight;
    final searchBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(pillRadius),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.20),
        width: 0.8,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            height: pillHeight,
            child: TextField(
              key: _guideSearchKey,
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: marketplaceSearchHint(context),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: pillHeight,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: AgroAccentColors.marketplaceChipGreen,
                enabledBorder: searchBorder,
                focusedBorder: searchBorder.copyWith(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.40),
                    width: 1,
                  ),
                ),
                border: searchBorder,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                      Row(
                        children: [
                          Icon(
                            Icons.gps_fixed,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'search_radius_label'.tr(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          if (_isLoadingLocation)
                            RotationTransition(
                              turns: _locationRefreshSpin,
                              child: Icon(
                                Icons.refresh,
                                color: Colors.white.withValues(alpha: 0.95),
                                size: 22,
                              ),
                            )
                          else
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              icon: Icon(
                                Icons.refresh,
                                color: Colors.white.withValues(alpha: 0.95),
                                size: 22,
                              ),
                              tooltip: 'search_refresh_location'.tr(),
                              onPressed: () => _refreshBuyerLocation(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        key: _guideRadiusKey,
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: SearchRadius.selectable.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final radius = SearchRadius.selectable[index];
                            final isSelected = _selectedRadius == radius;
                            return AgroFilterChip(
                              label: _radiusLabel(radius),
                              variant: isSelected
                                  ? AgroFilterChipVariant.whiteSelected
                                  : AgroFilterChipVariant.inactive,
                              onTap: () => _onRadiusChanged(radius),
                              margin: EdgeInsets.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                            );
                          },
                        ),
                      ),
                      if (_locationMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _locationMessage!,
                          style: TextStyle(
                            color: needsLocation
                                ? Colors.amber[100]
                                : Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      MarketplaceCategoryScrollBar(
                        key: _guideCategoriesKey,
                        selectedCategory: _selectedCategory,
                        onCategorySelected: (cat) => setState(() {
                          _selectedCategory = cat;
                          _currentPage = 1;
                        }),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: MarketplaceVetMapTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VetFinderScreen(
                                initialQuery: _searchQuery.trim().length >= 2
                                    ? _searchQuery.trim()
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        key: _guideTypeKey,
                        height: 35,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _productionFilters.length,
                          itemBuilder: (context, index) {
                            final type = _productionFilters[index];
                            final isSelected = _selectedType == type;
                            final variant = isSelected
                                ? AgroFilterChipVariant.whiteSelected
                                : AgroFilterChipVariant.inactive;
                            return AgroFilterChip(
                              label: ProductionTypes.label(type),
                              variant: variant,
                              onTap: () => setState(() {
                                _selectedType = type;
                                _currentPage = 1;
                              }),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  List<RankedProduct> _applyMarketplaceBoost(
    List<RankedProduct> ranked,
    Set<String> boostedSellerIds,
  ) {
    if (boostedSellerIds.isEmpty) return ranked;

    final boosted = <RankedProduct>[];
    final regular = <RankedProduct>[];

    for (final entry in ranked) {
      if (boostedSellerIds.contains(entry.product.sellerId)) {
        boosted.add(entry);
      } else {
        regular.add(entry);
      }
    }

    return [...boosted, ...regular];
  }

  Set<String> _boostedSellerIdsFromSnapshot(QuerySnapshot snapshot) {
    final ids = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final role = AppUser.normalizeRoleAlias(data['role']?.toString());
      final tier = data['subscriptionTier']?.toString() ?? '';
      final premiumApproved =
          data['premiumApprovalStatus']?.toString().toUpperCase() == 'APPROVED';
      if (role == 'pharmacy' &&
          tier == 'pharmacy_license' &&
          premiumApproved) {
        ids.add(doc.id);
      }
    }
    return ids;
  }

  Widget _buildVetSearchSection() {
    if (_searchQuery.trim().length < 2) return const SizedBox.shrink();

    if (_isSearchingVets) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            color: AgroAccentColors.headerGreenActive,
          ),
        ),
      );
    }

    if (_vetSearchResults.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'vet_search_results_title'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          ..._vetSearchResults.map(
            (vet) => Card(
              child: ListTile(
                onTap: () => showVetProfileSheet(
                  context: context,
                  ref: ref,
                  vet: vet,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.green[50],
                  child: Icon(Icons.medical_services, color: Colors.green[800]),
                ),
                title: Text(vet.name),
                subtitle: Text(
                  [
                    if (vet.address.isNotEmpty) vet.address,
                    if (vet.distanceKm != null)
                      '${vet.distanceKm!.toStringAsFixed(1)} km',
                    if (!vet.hasLocation) 'vet_map_no_location'.tr(),
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vet.isPremium)
                      Icon(Icons.verified, color: Colors.green[700]),
                    if (vet.hasLocation)
                      IconButton(
                        tooltip: 'vet_navigate'.tr(),
                        icon: Icon(Icons.directions, color: Colors.blue[700]),
                        onPressed: () => openVetDirections(vet),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProductGrid({
    required List<RankedProduct> pageItems,
    required int currentPage,
    required int totalPages,
  }) {
    return Column(
      key: _guideGridKey,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio:
                AgroAccentColors.marketplaceProductCardAspectRatio,
          ),
          itemCount: pageItems.length,
          itemBuilder: (context, index) {
            return _buildProductGridCard(pageItems[index]);
          },
        ),
        MarketplacePaginationBar(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageSelected: (page) => setState(() => _currentPage = page),
          compactNavigation: true,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStatusMessage({
    required Widget icon,
    required String message,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 16,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartProvider).length;
    final unreadMessages = ref.watch(navigationBadgesProvider).unreadMessages;
    final needsLocation = !_selectedRadius.isAll;
    final notificationIntent = ref.watch(notificationIntentProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AgroAccentColors.marketplaceUnifiedGreen,
      appBar: AgroGlassAppBar(
        unifiedMarketplaceHeader: true,
        title: Text(
          'marketplace_title'.tr(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          const NotificationsBellButton(),
          FarmerHelperIconButton(guideSteps: _guideSteps),
          AgroHeaderIconButton(
            icon: Icons.chat_bubble_outline,
            badgeCount: unreadMessages,
            tooltip: 'chat_my_messages'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FarmerChatListScreen(),
              ),
            ),
          ),
          AgroHeaderIconButton(
            icon: Icons.receipt_long_outlined,
            tooltip: 'buyer_orders_tooltip'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BuyerOrdersScreen(),
              ),
            ),
          ),
          AgroHeaderIconButton(
            icon: Icons.shopping_cart_outlined,
            badgeCount: cartCount,
            tooltip: 'cart_title'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: AgroAccentColors.marketplaceUnifiedGreen,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            bottom: ScrollBottomPadding.insetMainTab(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notificationIntent?.target == NotificationTarget.newProduct)
                const NotificationContextBanner(),
              _buildSearchHeader(),
              _buildVetSearchSection(),
              _buildProductStreams(needsLocation: needsLocation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductStreams({required bool needsLocation}) {
    final productsStream = _productsStream;
    final hiddenStream = _hiddenSellersStream;
    final sellersStream = _sellerSettingsStream;
    if (productsStream == null ||
        hiddenStream == null ||
        sellersStream == null) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(
            color: AgroAccentColors.headerGreenActive,
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: productsStream,
      builder: (context, productSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: hiddenStream,
          builder: (context, hiddenSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: sellersStream,
              builder: (context, sellerSnapshot) {
                if ((productSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !productSnapshot.hasData) ||
                    (hiddenSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !hiddenSnapshot.hasData)) {
                  return Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AgroAccentColors.headerGreenActive,
                      ),
                    ),
                  );
                }

                        if (!productSnapshot.hasData ||
                            productSnapshot.data!.docs.isEmpty) {
                          return _buildStatusMessage(
                            icon: Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            message: 'buyer_no_products'.tr(),
                          );
                        }

                        final hiddenIds = hiddenSnapshot.hasData
                            ? hiddenSnapshot.data!.docs
                                .map((d) => d.id)
                                .toSet()
                            : <String>{};

                        final sellerSettings = sellerSnapshot.hasData
                            ? _sellerSettingsFromSnapshot(
                                sellerSnapshot.data!,
                              )
                            : <String, FarmerShopSettings>{};

                        final allProducts = productSnapshot.data!.docs
                            .map((doc) => Product.fromFirestore(doc))
                            .toList();

                        final productRepo = ref.read(productRepositoryProvider);
                        for (final product in allProducts) {
                          if (product.needsHarvestTransition &&
                              _harvestTransitionRequested
                                  .add(product.id)) {
                            productRepo.ensureHarvestTransition(product);
                          }
                        }

                        final textFiltered =
                            _filterProducts(allProducts, hiddenIds);

                        if (needsLocation &&
                            _buyerPosition == null &&
                            !_isLoadingLocation) {
                          return _buildStatusMessage(
                            icon: Icon(
                              Icons.location_off_outlined,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            message: 'search_location_required'.tr(),
                            action: ElevatedButton.icon(
                              onPressed: _refreshBuyerLocation,
                              icon: const Icon(Icons.my_location),
                              label: Text('search_enable_location'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          );
                        }

                        final boostedSellerIds = sellerSnapshot.hasData
                            ? _boostedSellerIdsFromSnapshot(
                                sellerSnapshot.data!,
                              )
                            : <String>{};

                        final ranked = _applyMarketplaceBoost(
                          _searchLocationService.filterAndSort(
                            products: textFiltered,
                            sellerSettings: sellerSettings,
                            radius: _selectedRadius,
                            buyerPosition: _buyerPosition,
                          ),
                          boostedSellerIds,
                        );

                        if (ranked.isEmpty) {
                          return _buildStatusMessage(
                            icon: Icon(
                              Icons.search_off,
                              size: 60,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            message: needsLocation
                                ? 'search_no_results_radius'.tr(
                                    namedArgs: {
                                      'km': _selectedRadius.maxKm!
                                          .toStringAsFixed(0),
                                    },
                                  )
                                : 'search_no_results'.tr(),
                          );
                        }

                        final totalPages = _totalPages(ranked.length);
                        final currentPage = _currentPage.clamp(1, totalPages);
                        if (currentPage != _currentPage) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _currentPage = currentPage);
                            }
                          });
                        }
                        final pageItems = _pageItems(ranked, currentPage);

                        return _buildProductGrid(
                          pageItems: pageItems,
                          currentPage: currentPage,
                          totalPages: totalPages,
                        );
                      },
                    );
                  },
                );
              },
    );
  }
}
