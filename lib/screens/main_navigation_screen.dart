import 'dart:async';

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
import '../providers/forum_activity_provider.dart';
import '../providers/navigation_badges_provider.dart';
import '../providers/notification_navigation_provider.dart';
import '../providers/subscription_provider.dart';
import '../utils/upcoming_product_helper.dart';
import '../services/forum_activity_alert_listener.dart';
import '../widgets/notification_context_banner.dart';
import '../services/company_catalog_prefs.dart';
import '../widgets/farmer_welcome_dialog.dart';
import '../widgets/pending_verification_banner.dart';
import '../features/admin/widgets/admin_role_switcher.dart';
import '../widgets/agro_glass_chrome.dart';
import '../widgets/premium_gate.dart';
import '../services/payment_service.dart';
import '../services/in_app_inbox_sync.dart';
import '../repositories/in_app_notification_repository.dart';
import '../services/notification_service.dart';
import '../services/user_presence_service.dart';
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

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen>
    with WidgetsBindingObserver {
  static String? _localeRestoredForUid;

  late int _selectedIndex;
  bool _localeRestored = false;
  bool _welcomeChecked = false;
  List<Widget>? _cachedScreens;
  String? _cachedScreensRole;
  Locale? _cachedScreensLocale;
  final Set<int> _visitedTabIndices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialTabIndex;
    _visitedTabIndices.add(widget.initialTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(NotificationService().ensurePushReady());
      ref.read(userPresenceServiceProvider).start();
      NotificationNavigationBridge.register(
        ref.read(notificationIntentProvider.notifier),
      );
      NotificationNavigationBridge.registerTabSwitcher(_applyNotificationIntent);
      NotificationNavigationBridge.registerInboxSync(
        (intent) => InAppInboxSync(
          ref.read(inAppNotificationRepositoryProvider),
        ).recordIntent(intent),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreUserLocale());
  }

  @override
  void dispose() {
    NotificationNavigationBridge.unregister();
    ref.read(userPresenceServiceProvider).stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final presence = ref.read(userPresenceServiceProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        presence.onForeground();
        unawaited(NotificationService().ensurePushReady());
        NotificationService().flushPendingNavigation();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        presence.onBackground();
    }
  }

  Future<void> _restoreUserLocale() async {
    if (_localeRestored) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    if (_localeRestoredForUid == user.uid) {
      _localeRestored = true;
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.serverAndCache));
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
    if (option != null && context.locale != option.locale) {
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
    _localeRestoredForUid = user.uid;
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
      setState(() {
        _selectedIndex = defaultTabIndexForRole(nextRole);
        _resetVisitedTabs();
      });
    } else if (hadSeller && !hasSeller) {
      setState(() {
        _selectedIndex = 0;
        _resetVisitedTabs();
      });
    } else if (_selectedIndex >= _tabCountForRole(nextRole)) {
      setState(() {
        _selectedIndex = 0;
        _resetVisitedTabs();
      });
    }
  }

  void _resetVisitedTabs() {
    _visitedTabIndices
      ..clear()
      ..add(_selectedIndex);
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabIndices.add(index);
    });
  }

  void _applyNotificationIntent(NotificationNavigationIntent intent) {
    final role = ref.read(effectiveFirestoreRoleProvider);
    final profileIndex = _tabCountForRole(role) - 1;

    switch (intent.target) {
      case NotificationTarget.weather:
      case NotificationTarget.lowStock:
      case NotificationTarget.orders:
        if (hasSellerTab(role)) {
          _selectTab(1);
        }
        break;
      case NotificationTarget.buyerOrders:
        break;
      case NotificationTarget.newProduct:
        _selectTab(0);
        break;
      case NotificationTarget.vetIntake:
      case NotificationTarget.vetResponse:
        if (role == 'veterinarian') {
          _selectTab(profileIndex);
        }
        break;
      case NotificationTarget.chatMessage:
        break;
      case NotificationTarget.forumTopic:
      case NotificationTarget.forumReply:
        _selectTab(hasSellerTab(role) ? 3 : 2);
        break;
    }
  }

  int _tabCountForRole(String role) => hasSellerTab(role) ? 6 : 5;

  List<Widget> _screensForRole(String role, Locale locale) {
    if (_cachedScreens != null &&
        _cachedScreensRole == role &&
        _cachedScreensLocale == locale) {
      return _cachedScreens!;
    }

    _cachedScreensRole = role;
    _cachedScreensLocale = locale;
    if (hasSellerTab(role)) {
      _cachedScreens = [
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
    } else {
      _cachedScreens = [
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
    return _cachedScreens!;
  }

  List<Widget> _lazyScreensForRole(String role, Locale locale) {
    final screens = _screensForRole(role, locale);
    return List.generate(screens.length, (index) {
      if (!_visitedTabIndices.contains(index)) {
        return SizedBox.shrink(key: ValueKey('nav_lazy_$index'));
      }
      return screens[index];
    });
  }

  Widget _dotIcon({
    required IconData icon,
    required IconData activeIcon,
    required bool showDot,
    required bool active,
  }) {
    final child = Icon(active ? activeIcon : icon);
    if (!showDot) return child;
    return Badge(
      isLabelVisible: false,
      backgroundColor: Colors.amberAccent,
      smallSize: 8,
      child: child,
    );
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
    bool forumHasActivity,
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
          icon: _dotIcon(
            icon: Icons.question_answer_outlined,
            activeIcon: Icons.question_answer,
            showDot: forumHasActivity,
            active: false,
          ),
          activeIcon: _dotIcon(
            icon: Icons.question_answer_outlined,
            activeIcon: Icons.question_answer,
            showDot: forumHasActivity,
            active: true,
          ),
          label: navLabel('nav_forum', 'Forum'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.landscape_outlined),
          activeIcon: const Icon(Icons.landscape),
          label: navLabel('nav_community', 'Community'),
        ),
        BottomNavigationBarItem(
          icon: _badgedIcon(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            count: badges.profileTabBadge,
            active: false,
          ),
          activeIcon: _badgedIcon(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            count: badges.profileTabBadge,
            active: true,
          ),
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
        icon: _dotIcon(
          icon: Icons.question_answer_outlined,
          activeIcon: Icons.question_answer,
          showDot: forumHasActivity,
          active: false,
        ),
        activeIcon: _dotIcon(
          icon: Icons.question_answer_outlined,
          activeIcon: Icons.question_answer,
          showDot: forumHasActivity,
          active: true,
        ),
        label: navLabel('nav_forum', 'Forum'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.landscape_outlined),
        activeIcon: const Icon(Icons.landscape),
        label: navLabel('nav_community', 'Community'),
      ),
      BottomNavigationBarItem(
        icon: _badgedIcon(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          count: badges.profileTabBadge,
          active: false,
        ),
        activeIcon: _badgedIcon(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          count: badges.profileTabBadge,
          active: true,
        ),
        label: navLabel('nav_profile', 'Profile'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(firestoreUserRoleProvider);
    final userAsync = ref.watch(userDocProvider);
    final badges = ref.watch(navigationBadgesProvider);
    final forumHasActivity = ref.watch(forumHasActivityProvider);

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

    ref.listen<NotificationNavigationIntent?>(
      notificationIntentProvider,
      (previous, next) {
        if (next == null || !mounted) return;
        _applyNotificationIntent(next);
      },
    );

    final authUser = ref.watch(authStateProvider).valueOrNull;
    final role = ref.watch(effectiveFirestoreRoleProvider);
    final fallbackRole = authUser?.roleFirestore ?? '';
    final effectiveRole =
        role.isNotEmpty ? role : fallbackRole;

    // Ne prekrivaj cijeli UI spinnerom kad provideri reloadaju u pozadini.
    if (effectiveRole.isEmpty &&
        (roleAsync.isLoading || userAsync.isLoading)) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (effectiveRole.isEmpty &&
        (roleAsync.hasError || userAsync.hasError)) {
      return Scaffold(
        body: Center(child: Text('main_profile_load_error'.tr())),
      );
    }

    if (effectiveRole.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_welcomeChecked && !UpcomingProductHelper.isCompanyRole(effectiveRole)) {
      _welcomeChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FarmerWelcomeDialog.showIfNeeded(context);
      });
    } else if (!_welcomeChecked &&
        UpcomingProductHelper.isCompanyRole(effectiveRole)) {
      _welcomeChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCompanyCatalogIfNeeded();
      });
    } else if (!_welcomeChecked) {
      _welcomeChecked = true;
    }

    return ForumActivityAlertListener(
      child: Scaffold(
        extendBody: true,
        body: Column(
          children: [
            const AdminPreviewBanner(),
            const NotificationContextBanner(),
            PendingVerificationBanner(key: ValueKey(context.locale.toString())),
            Expanded(
              child: IndexedStack(
                key: ValueKey('nav_stack_$effectiveRole'),
                index: _selectedIndex.clamp(0, _tabCountForRole(effectiveRole) - 1),
                children: _lazyScreensForRole(effectiveRole, context.locale),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AgroGlassBottomNav(
          key: ValueKey('nav_bar_${effectiveRole}_${context.locale}'),
          currentIndex:
              _selectedIndex.clamp(0, _tabCountForRole(effectiveRole) - 1),
          onTap: _selectTab,
          items: _navItemsForRole(effectiveRole, badges, forumHasActivity),
        ),
      ),
    );
  }
}
