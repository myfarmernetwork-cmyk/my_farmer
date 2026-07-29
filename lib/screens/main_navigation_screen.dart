import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/buyer/buyer_home_screen.dart';
import '../features/community/screens/community_feed_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/seller/company_catalog_screen.dart';
import '../features/seller/farmer_home_screen.dart';
import '../screens/forum_screen.dart';
import '../models/app_user.dart';
import '../models/premium_access.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_role_preview_provider.dart';
import '../providers/locale_settings_provider.dart';
import '../providers/navigation_badges_provider.dart';
import '../providers/subscription_provider.dart';
import '../utils/upcoming_product_helper.dart';
import '../services/seller_order_alert_listener.dart';
import '../services/company_catalog_prefs.dart';
import '../widgets/farmer_welcome_dialog.dart';
import '../widgets/pending_verification_banner.dart';
import '../features/admin/widgets/admin_role_switcher.dart';
import '../widgets/premium_gate.dart';
import '../services/payment_service.dart';
import 'plant_scanner_screen.dart';

bool hasSellerTab(String role) {
  final canonical = AppUser.normalizeRoleAlias(role);
  return canonical == 'hobby_farmer' ||
      canonical == 'professional_farmer' ||
      canonical == 'farmer' ||
      canonical == 'services' ||
      canonical == 'pharmacy' ||
      canonical == 'veterinarian';
}

int defaultTabIndexForRole(String role) {
  final canonical = AppUser.normalizeRoleAlias(role);
  if (canonical == 'veterinarian') return 5;
  if (hasSellerTab(role) &&
      (canonical == 'hobby_farmer' ||
          canonical == 'professional_farmer' ||
          canonical == 'pharmacy')) {
    return 1;
  }
  return 0;
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  late int _selectedIndex;
  bool _localeRestored = false;
  bool _welcomeChecked = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreUserLocale());
  }

  Future<void> _restoreUserLocale() async {
    if (_localeRestored) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data == null || !mounted) return;

    final storedRegion = data['currencyRegion'] as String?;
    final paymentCountry = data['paymentCountryCode'] as String?;
    if (paymentCountry != null && paymentCountry.isNotEmpty) {
      PaymentService.cachePaymentCountryCode(paymentCountry);
    }
    final role = AppUser.parseRole(data['role']?.toString());
    final option =
        AppLocaleOption.fromStorageKey(data['preferredLanguage'] as String?);
    final locale = option?.locale ?? context.locale;
    if (option != null) {
      await context.setLocale(option.locale);
    }

    String region;
    if (locale.languageCode == 'sv' && role == UserRole.veterinarian) {
      region = 'se';
    } else {
      await PaymentService.resolveDeviceCountry();
      region = resolveCurrencyRegionForUser(
        locale: locale,
        storedRegion: storedRegion,
        deviceCountryCode: PaymentService.cachedGpsVerifiedCountryCode,
        paymentCountryCode: paymentCountry,
        role: role,
      );
      final locked = gpsLockedCurrencyRegion(
        PaymentService.cachedGpsVerifiedCountryCode ?? '',
        locale.languageCode,
      );
      if (locked != null || storedRegion != region) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'currencyRegion': region},
          SetOptions(merge: true),
        );
      }
    }

    ref.read(currencyRegionProvider.notifier).state = region;

    _localeRestored = true;
  }

  Future<void> _openCompanyCatalogIfNeeded() async {
    if (!mounted) return;
    if (await CompanyCatalogPrefs.hasAutoOpenedCatalog()) return;
    await CompanyCatalogPrefs.markAutoOpenedCatalog();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CompanyCatalogScreen()),
    );
  }

  void _handleRoleChange(String? previousRole, String nextRole) {
    final hadSeller = previousRole != null && hasSellerTab(previousRole);
    final hasSeller = hasSellerTab(nextRole);

    if (previousRole == nextRole) return;

    if (!hadSeller && hasSeller) {
      setState(() => _selectedIndex = defaultTabIndexForRole(nextRole));
    } else if (hadSeller && !hasSeller) {
      setState(() => _selectedIndex = 0);
    } else if (_selectedIndex >= _tabCountForRole(nextRole)) {
      setState(() => _selectedIndex = 0);
    }
  }

  int _tabCountForRole(String role) => hasSellerTab(role) ? 6 : 5;

  List<Widget> _screensForRole(String role, Locale locale) {
    if (hasSellerTab(role)) {
      return [
        const BuyerHomeScreen(),
        FarmerHomeScreen(key: ValueKey('seller_${role}_${locale.languageCode}')),
        PremiumFeatureScreen(
          feature: PremiumFeature.aiScanner,
          titleKey: 'scanner_premium_title',
          descriptionKey: 'scanner_premium_desc',
          icon: Icons.biotech,
          child: PlantScannerScreen(key: ValueKey('scanner_$locale')),
        ),
        const ForumScreen(),
        CommunityFeedScreen(key: ValueKey('community_$locale')),
        ProfileScreen(key: ValueKey('profile_$role')),
      ];
    }
    return [
      const BuyerHomeScreen(),
      PremiumFeatureScreen(
        feature: PremiumFeature.aiScanner,
        titleKey: 'scanner_premium_title',
        descriptionKey: 'scanner_premium_desc',
        icon: Icons.biotech,
        child: PlantScannerScreen(key: ValueKey('scanner_$locale')),
      ),
      const ForumScreen(),
      CommunityFeedScreen(key: ValueKey('community_$locale')),
      ProfileScreen(key: ValueKey('profile_$role')),
    ];
  }

  Widget _badgedIcon({
    required IconData icon,
    required IconData activeIcon,
    required int count,
    required bool active,
  }) {
    final child = Icon(active ? activeIcon : icon);
    if (count <= 0) return child;
    return Badge(
      label: Text('$count'),
      backgroundColor: Colors.red,
      child: child,
    );
  }

  List<BottomNavigationBarItem> _navItemsForRole(
    String role,
    NavigationBadges badges,
  ) {
    String navLabel(String key, String enFallback) {
      final translated = key.tr();
      return translated != key ? translated : enFallback;
    }

    if (hasSellerTab(role)) {
      return [
        BottomNavigationBarItem(
          icon: const Icon(Icons.shopping_basket_outlined),
          activeIcon: const Icon(Icons.shopping_basket),
          label: navLabel('nav_marketplace', 'Market'),
        ),
        BottomNavigationBarItem(
          icon: _badgedIcon(
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront,
            count: badges.sellerTabBadge,
            active: false,
          ),
          activeIcon: _badgedIcon(
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront,
            count: badges.sellerTabBadge,
            active: true,
          ),
          label: navLabel('nav_my_products', 'My products'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.biotech_outlined),
          activeIcon: const Icon(Icons.biotech),
          label: navLabel('nav_ai_scanner', 'AI Scanner'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.forum_outlined),
          activeIcon: const Icon(Icons.forum),
          label: navLabel('nav_forum', 'Forum'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.landscape_outlined),
          activeIcon: const Icon(Icons.landscape),
          label: navLabel('nav_community', 'Community'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline),
          activeIcon: const Icon(Icons.person),
          label: navLabel('nav_profile', 'Profile'),
        ),
      ];
    }
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.shopping_basket_outlined),
        activeIcon: const Icon(Icons.shopping_basket),
        label: navLabel('nav_marketplace', 'Market'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.biotech_outlined),
        activeIcon: const Icon(Icons.biotech),
        label: navLabel('nav_ai_scanner', 'AI Scanner'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.forum_outlined),
        activeIcon: const Icon(Icons.forum),
        label: navLabel('nav_forum', 'Forum'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.landscape_outlined),
        activeIcon: const Icon(Icons.landscape),
        label: navLabel('nav_community', 'Community'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
        label: navLabel('nav_profile', 'Profile'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(firestoreUserRoleProvider);
    final userAsync = ref.watch(userDocProvider);
    final badges = ref.watch(navigationBadgesProvider);

    ref.listen<AsyncValue<String?>>(firestoreUserRoleProvider, (previous, next) {
      final prevRole = previous?.valueOrNull;
      final nextRole = next.valueOrNull;
      if (nextRole != null && nextRole.isNotEmpty && mounted) {
        _handleRoleChange(prevRole, nextRole);
      }
    });

    ref.listen<String>(adminRolePreviewProvider, (previous, next) {
      if (!mounted) return;
      if (!ref.read(adminPremiumBypassProvider)) return;
      _handleRoleChange(previous, next);
    });

    if (roleAsync.isLoading || userAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (roleAsync.hasError || userAsync.hasError) {
      return Scaffold(
        body: Center(child: Text('main_profile_load_error'.tr())),
      );
    }

    final role = ref.watch(effectiveFirestoreRoleProvider);
    if (role.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_welcomeChecked && !UpcomingProductHelper.isCompanyRole(role)) {
      _welcomeChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FarmerWelcomeDialog.showIfNeeded(context);
      });
    } else if (!_welcomeChecked && UpcomingProductHelper.isCompanyRole(role)) {
      _welcomeChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCompanyCatalogIfNeeded();
      });
    } else if (!_welcomeChecked) {
      _welcomeChecked = true;
    }

    return SellerOrderAlertListener(
      role: role,
      child: Scaffold(
        body: Column(
          children: [
            const AdminPreviewBanner(),
            PendingVerificationBanner(key: ValueKey(context.locale.toString())),
            Expanded(
              child: IndexedStack(
                key: ValueKey('nav_stack_$role'),
                index: _selectedIndex.clamp(0, _tabCountForRole(role) - 1),
                children: _screensForRole(role, context.locale),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          key: ValueKey('nav_bar_${role}_${context.locale}'),
          currentIndex: _selectedIndex.clamp(0, _tabCountForRole(role) - 1),
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.green[700],
          unselectedItemColor: Colors.grey,
          items: _navItemsForRole(role, badges),
        ),
      ),
    );
  }
}
