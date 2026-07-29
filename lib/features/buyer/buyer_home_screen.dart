import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/auth_provider.dart';
import '../../models/app_user.dart';
import '../../models/farmer_shop_settings.dart';
import '../../services/vet_proximity_radar_service.dart';
import '../../models/product.dart';
import '../../models/search_radius.dart';
import '../../services/search_location_service.dart';
import '../../utils/product_categories.dart';
import '../../utils/production_types.dart';
import '../../repositories/product_repository.dart';
import '../../models/screen_guide_step.dart';
import '../../widgets/farmer_helper_button.dart';
import '../../widgets/harvest_countdown_overlay.dart';
import '../../widgets/product_card.dart';
import '../../widgets/translated_text.dart';
import 'buyer_orders_screen.dart';
import 'cart_provider.dart';
import 'cart_screen.dart';
import 'product_details_screen.dart';

String marketplaceSearchHint(BuildContext context) {
  const placeholderKey = 'search_placeholder';
  final placeholder = placeholderKey.tr();
  if (placeholder != placeholderKey) return placeholder;
  return 'buyer_search_hint'.tr();
}

class BuyerHomeScreen extends ConsumerStatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  ConsumerState<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends ConsumerState<BuyerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchLocationService _searchLocationService = SearchLocationService();

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

  static const _categoryFilters = ProductCategories.filterCodes;
  static const _productionFilters = ProductionTypes.filterCodes;
  static const _productsPerPage = 12;

  int _currentPage = 1;

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
    _refreshBuyerLocation(showErrors: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshBuyerLocation({bool showErrors = true}) async {
    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
    });

    final position = await _searchLocationService.getBuyerPosition();

    if (!mounted) return;

    setState(() {
      _buyerPosition = position;
      _isLoadingLocation = false;
      if (position == null && !_selectedRadius.isAll) {
        _locationMessage = 'search_location_required'.tr();
      } else if (position != null) {
        _locationMessage = null;
      } else if (showErrors) {
        _locationMessage = 'search_location_optional'.tr();
      }
    });
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

    if (!radius.isAll && _buyerPosition == null) {
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
    final vets =
        await ref.read(vetProximityRadarServiceProvider).searchVetsByName(query);
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

      final matchesSearch = p.name
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == ProductCategories.all ||
          p.categoryCode == _selectedCategory;
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

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageSelected,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: currentPage > 1
                ? () => onPageSelected(currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            label: Text(
              'page_previous'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green[800],
              disabledForegroundColor: Colors.grey[400],
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalPages, (index) {
                  final pageNumber = index + 1;
                  final isActive = pageNumber == currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: isActive ? null : () => onPageSelected(pageNumber),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.blue[700] : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? Colors.blue[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          '$pageNumber',
                          style: TextStyle(
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.w500,
                            color: isActive ? Colors.white : Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: currentPage < totalPages
                ? () => onPageSelected(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            label: Text(
              'page_next'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(
              foregroundColor: Colors.green[800],
              disabledForegroundColor: Colors.grey[400],
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    final image = Image.network(
      product.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[200],
        child: Icon(
          product.isService ? Icons.build : Icons.image,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );

    if (product.isHarvestCountdownActive && product.harvestDateTime != null) {
      return HarvestCountdownOverlay(
        harvestDateTime: product.harvestDateTime!,
        isDelivery: product.isDeliveryUpcoming,
        upcomingMode: product.upcomingMode,
        child: image,
      );
    }

    return image;
  }

  Widget _buildProductGridCard(RankedProduct entry) {
    final product = entry.product;
    final distance = entry.distanceKm;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: product),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 11,
              child: ProductCardImage(
                isUnavailable: product.isUnavailable,
                child: _buildProductImage(product),
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TranslatedText(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ProductCardPriceText(
                      price: product.price,
                      originalCurrency: product.originalCurrency,
                      unit: product.displayUnit,
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${_sellerEmoji(product)} ${product.sellerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              product.categoryLabel(context.locale.languageCode),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ),
                        if (distance != null) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'search_distance_km'.tr(
                                  namedArgs: {
                                    'km': distance.toStringAsFixed(1),
                                  },
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    final needsLocation = !_selectedRadius.isAll;

    return Container(
      color: Colors.green[700],
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: _guideSearchKey,
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: marketplaceSearchHint(context),
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.radar,
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
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                )
              else
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.my_location,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 20,
                  ),
                  tooltip: 'search_refresh_location'.tr(),
                  onPressed: _refreshBuyerLocation,
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
                return GestureDetector(
                  onTap: () => _onRadiusChanged(radius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _radiusLabel(radius),
                      style: TextStyle(
                        color: isSelected ? Colors.green[800] : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
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
          const SizedBox(height: 8),
          SizedBox(
            key: _guideCategoriesKey,
            height: 35,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categoryFilters.length,
              itemBuilder: (context, index) {
                final cat = _categoryFilters[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = cat;
                    _currentPage = 1;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ProductCategories.label(cat),
                      style: TextStyle(
                        color: isSelected ? Colors.green[700] : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            key: _guideTypeKey,
            height: 35,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _productionFilters.length,
              itemBuilder: (context, index) {
                final type = _productionFilters[index];
                final isSelected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.amber[600]
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ProductionTypes.label(type),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
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
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ..._vetSearchResults.map(
            (vet) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[50],
                  child: Icon(Icons.medical_services, color: Colors.green[800]),
                ),
                title: Text(vet.name),
                subtitle: Text(
                  vet.address.isEmpty ? vet.phone : vet.address,
                ),
                trailing: vet.isPremium
                    ? Icon(Icons.verified, color: Colors.green[700])
                    : null,
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.70,
          ),
          itemCount: pageItems.length,
          itemBuilder: (context, index) =>
              _buildProductGridCard(pageItems[index]),
        ),
        _buildPaginationBar(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageSelected: (page) => setState(() => _currentPage = page),
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
            style: TextStyle(color: Colors.grey[700], fontSize: 16),
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
    final needsLocation = !_selectedRadius.isAll;
    final roleAsync = ref.watch(firestoreUserRoleProvider);
    final liveRole = roleAsync.valueOrNull ?? '';

    if (roleAsync.isLoading || liveRole.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('marketplace_title'.tr()),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          FarmerHelperIconButton(guideSteps: _guideSteps),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'buyer_orders_tooltip'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BuyerOrdersScreen(),
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'cart_title'.tr(),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchHeader(),
            _buildVetSearchSection(),
            _buildProductStreams(needsLocation: needsLocation),
          ],
        ),
      ),
    );
  }

  Widget _buildProductStreams({required bool needsLocation}) {
    return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, productSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('isPublicProfile', isEqualTo: false)
                      .snapshots(),
                  builder: (context, hiddenSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', whereIn: _sellerRoles)
                          .snapshots(),
                      builder: (context, sellerSnapshot) {
                        if (productSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            hiddenSnapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (!productSnapshot.hasData ||
                            productSnapshot.data!.docs.isEmpty) {
                          return _buildStatusMessage(
                            icon: Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[400],
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
                          if (product.needsHarvestTransition) {
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
                              color: Colors.grey[400],
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
                              color: Colors.grey[400],
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
