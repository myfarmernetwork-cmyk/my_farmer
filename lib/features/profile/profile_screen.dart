import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_version.dart';
import '../../screens/login_screen.dart';
import '../../models/app_user.dart';
import '../../models/premium_access.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_role_preview_provider.dart';
import '../../providers/subscription_provider.dart';
import '../admin/widgets/admin_role_switcher.dart';
import '../../widgets/premium_gate_dialog.dart';
import '../../widgets/farmer_help_widgets.dart';
import '../../screens/company_market_analytics_screen.dart';
import '../../widgets/company_catalog_guide.dart';
import '../../screens/land_measurement_screen.dart';
import '../../screens/my_animals_screen.dart';
import '../../utils/upcoming_product_helper.dart';
import '../../utils/farmer_guide_access.dart';
import '../community/widgets/user_community_gallery_grid.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../models/farmer_shop_settings.dart';
import '../../providers/locale_settings_provider.dart';
import '../../services/currency_service.dart';
import '../../services/address_geocoding_service.dart';
import '../../services/payment_service.dart';
import '../../utils/currency_region_parse.dart';
import '../../utils/firestore_error_helper.dart';
import '../../utils/farmer_shop_localization.dart';
import '../../utils/role_helpers.dart';
import '../../utils/weekday_localization.dart';
import '../../models/screen_guide_step.dart';
import '../../widgets/farmer_helper_button.dart';
import '../../widgets/firestore_error_panel.dart';
import '../../widgets/profile_subscription_card.dart';
import '../../widgets/profile_payment_methods_tile.dart';
import '../../widgets/profile_delete_account_tile.dart';
import '../../widgets/farmer_follower_count_badge.dart';
import '../../screens/roles_subscription_pdf_screen.dart';
import '../../screens/beta_test_pdf_screen.dart';
import '../legal/marketplace_terms_screen.dart';
import '../legal/privacy_policy_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  File? _image;
  bool _isUploading = false;
  late TabController _tabController;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _workingHoursController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _maxDeliveryController = TextEditingController();
  final _zone1MaxController = TextEditingController();
  final _zone1MinController = TextEditingController();
  final _zone2MaxController = TextEditingController();
  final _zone2MinController = TextEditingController();
  final _pickupFromController = TextEditingController();
  final _pickupToController = TextEditingController();
  final _deliveryFromController = TextEditingController();
  final _deliveryToController = TextEditingController();

  Map<String, dynamic>? _userData;
  bool _isEditing = false;
  int _selectedTabIndex = 0;
  bool _isAvailable = true;
  bool _offersPickup = true;
  bool _offersDelivery = false;
  double? _farmLat;
  double? _farmLng;
  String _orderCurrency = 'KM';
  String? _selectedLocaleKey;
  String? _currencyRegion;
  Object? _profileLoadErrorObject;
  bool _isLoadingProfile = true;
  final List<String> _selectedWorkingDays = [];
  final List<String> _selectedPickupDays = [];
  final List<String> _selectedDeliveryDays = [];

  final GlobalKey _guideTabsKey = GlobalKey();
  final GlobalKey _guideFarmerIdentityKey = GlobalKey();
  final GlobalKey _guideLanguageKey = GlobalKey();
  final GlobalKey _guideCurrencyKey = GlobalKey();
  final GlobalKey _guidePhoneKey = GlobalKey();
  final GlobalKey _guideAddressKey = GlobalKey();
  final GlobalKey _guidePaypalKey = GlobalKey();
  final GlobalKey _guideLandKey = GlobalKey();
  final GlobalKey _guideFarmKey = GlobalKey();
  final GlobalKey _guideShopHoursKey = GlobalKey();
  final GlobalKey _guideMinOrderKey = GlobalKey();
  final GlobalKey _guidePickupKey = GlobalKey();
  final GlobalKey _guideDeliveryInfoKey = GlobalKey();
  final GlobalKey _guideDeliveryZonesKey = GlobalKey();
  bool _profileGuideTourSuppressed = false;

  void _syncProfileGuideSuppression({
    required String? role,
    required Map<String, dynamic>? userData,
    required UserRole parsedRole,
  }) {
    _profileGuideTourSuppressed = FarmerGuideAccess.isCompanyAccount(
      role: role,
      parsedRole: parsedRole,
      userData: userData,
    );
  }

  bool _profileGuideEnabled({
    required String? role,
    required Map<String, dynamic>? userData,
    required UserRole parsedRole,
  }) {
    return FarmerGuideAccess.isGuideEnabled(
      role: role,
      parsedRole: parsedRole,
      userData: userData,
    );
  }

  List<ScreenGuideStep> _guideStepsForRole({
    required String? role,
    required Map<String, dynamic>? userData,
    required UserRole parsedRole,
  }) {
    if (_profileGuideTourSuppressed ||
        !_profileGuideEnabled(
          role: role,
          userData: userData,
          parsedRole: parsedRole,
        )) {
      return [];
    }

    return [
        ScreenGuideStep(
          targetKey: _guideTabsKey,
          titleKey: 'guide_profile_tabs_title',
          bodyKey: 'guide_profile_tabs_body',
          highlightPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 14,
          ),
        ),
        ScreenGuideStep(
          targetKey: _guideFarmerIdentityKey,
          titleKey: 'guide_profile_identity_title',
          bodyKey: 'guide_profile_identity_body',
        ),
        ScreenGuideStep(
          targetKey: _guideLanguageKey,
          titleKey: 'guide_profile_settings_title',
          bodyKey: 'guide_profile_settings_body',
        ),
        ScreenGuideStep(
          targetKey: _guideCurrencyKey,
          titleKey: 'guide_profile_currency_title',
          bodyKey: 'guide_profile_currency_body',
        ),
        ScreenGuideStep(
          targetKey: _guidePhoneKey,
          titleKey: 'guide_profile_phone_title',
          bodyKey: 'guide_profile_phone_body',
        ),
        ScreenGuideStep(
          targetKey: _guideAddressKey,
          titleKey: 'guide_profile_address_title',
          bodyKey: 'guide_profile_address_body',
        ),
        ScreenGuideStep(
          targetKey: _guidePaypalKey,
          titleKey: 'guide_profile_payment_methods_title',
          bodyKey: 'guide_profile_payment_methods_body',
        ),
        ScreenGuideStep(
          targetKey: _guideLandKey,
          titleKey: 'guide_profile_land_title',
          bodyKey: 'guide_profile_land_body',
        ),
        ScreenGuideStep(
          targetKey: _guideFarmKey,
          titleKey: 'guide_profile_farm_number_title',
          bodyKey: 'guide_profile_farm_number_body',
        ),
        ScreenGuideStep(
          targetKey: _guideShopHoursKey,
          titleKey: 'guide_profile_shop_hours_title',
          bodyKey: 'guide_profile_shop_hours_body',
        ),
        ScreenGuideStep(
          targetKey: _guideMinOrderKey,
          titleKey: 'guide_profile_min_order_title',
          bodyKey: 'guide_profile_min_order_body',
        ),
        ScreenGuideStep(
          targetKey: _guidePickupKey,
          titleKey: 'guide_profile_pickup_title',
          bodyKey: 'guide_profile_pickup_body',
        ),
        ScreenGuideStep(
          targetKey: _guideDeliveryInfoKey,
          titleKey: 'guide_profile_delivery_info_title',
          bodyKey: 'guide_profile_delivery_info_body',
        ),
        ScreenGuideStep(
          targetKey: _guideDeliveryZonesKey,
          titleKey: 'guide_profile_delivery_zones_title',
          bodyKey: 'guide_profile_delivery_zones_body',
        ),
      ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _workingHoursController.dispose();
    _minOrderController.dispose();
    _maxDeliveryController.dispose();
    _zone1MaxController.dispose();
    _zone1MinController.dispose();
    _zone2MaxController.dispose();
    _zone2MinController.dispose();
    _pickupFromController.dispose();
    _pickupToController.dispose();
    _deliveryFromController.dispose();
    _deliveryToController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() {
      _profileLoadErrorObject = null;
      _isLoadingProfile = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _profileLoadErrorObject = const FirestoreNotSignedInException();
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));

      if (!mounted) return;

      final raw = doc.exists ? (doc.data() ?? {}) : <String, dynamic>{};
      final resolvedRole = AppUser.resolveRoleCanonical(raw);
      if (resolvedRole.isNotEmpty) {
        raw['role'] = resolvedRole;
      }
      final parsedRole = AppUser.parseRole(
        resolvedRole.isNotEmpty ? resolvedRole : raw['role']?.toString(),
      );
      _syncProfileGuideSuppression(
        role: resolvedRole.isNotEmpty ? resolvedRole : raw['role']?.toString(),
        userData: raw,
        parsedRole: parsedRole,
      );
      setState(() {
        _userData = raw;
        _isLoadingProfile = false;
        _profileLoadErrorObject = null;
        _nameController.text = _userData?['name'] ?? '';
        _phoneController.text = _userData?['phone'] ?? '';
        _addressController.text = _userData?['address'] ?? '';

        final shop = FarmerShopSettings.fromMap(_userData ?? {});
        _selectedWorkingDays
          ..clear()
          ..addAll(shop.workingDays);
        _workingHoursController.text = shop.workingHours;
        _minOrderController.text = shop.minimumOrderAmount > 0
            ? shop.minimumOrderAmount.toStringAsFixed(0)
            : '';
        _isAvailable = shop.isAvailable;
        _orderCurrency = shop.orderCurrency;
        _offersPickup = shop.offersPickup;
        _offersDelivery = shop.offersDelivery;
        _farmLat = shop.farmLat;
        _farmLng = shop.farmLng;
        _maxDeliveryController.text = shop.maxDeliveryDistanceKm > 0
            ? shop.maxDeliveryDistanceKm.toStringAsFixed(0)
            : '';
        _zone1MaxController.text = shop.deliveryZone1MaxKm > 0
            ? shop.deliveryZone1MaxKm.toStringAsFixed(0)
            : '';
        _zone1MinController.text = shop.deliveryZone1MinOrder > 0
            ? shop.deliveryZone1MinOrder.toStringAsFixed(0)
            : '';
        _zone2MaxController.text = shop.deliveryZone2MaxKm > 0
            ? shop.deliveryZone2MaxKm.toStringAsFixed(0)
            : '';
        _zone2MinController.text = shop.deliveryZone2MinOrder > 0
            ? shop.deliveryZone2MinOrder.toStringAsFixed(0)
            : '';
        _selectedPickupDays
          ..clear()
          ..addAll(shop.pickupDays);
        _selectedDeliveryDays
          ..clear()
          ..addAll(shop.deliveryDays);
        _pickupFromController.text = shop.pickupHoursFrom;
        _pickupToController.text = shop.pickupHoursTo;
        _deliveryFromController.text = shop.deliveryHoursFrom;
        _deliveryToController.text = shop.deliveryHoursTo;
        _selectedLocaleKey = _resolveInitialLocaleKey(
          _userData?['preferredLanguage'] as String?,
        );
        _currencyRegion =
            CurrencyRegionParse.normalize(_userData?['currencyRegion']);
      });
      await _syncCurrencyRegionWithDeviceLocation(
        userId: user.uid,
        persistIfAutoDetected: _currencyRegion == null || _currencyRegion!.isEmpty,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _profileLoadErrorObject = e;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _profileLoadErrorObject = e;
      });
    }
  }

  /// Ako korisnik nije ručno odabrao valutu, postavi je prema lokaciji uređaja.
  Future<void> _syncCurrencyRegionWithDeviceLocation({
    required String userId,
    required bool persistIfAutoDetected,
  }) async {
    final locale = context.locale;
    final role = AppUser.parseRole(_userData?['role']?.toString());

    if (locale.languageCode == 'sv' && role == UserRole.veterinarian) {
      if (!mounted) return;
      if (_currencyRegion == 'se' &&
          ref.read(currencyRegionProvider) == 'se') {
        return;
      }
      setState(() => _currencyRegion = 'se');
      ref.read(currencyRegionProvider.notifier).state = 'se';
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {'currencyRegion': 'se'},
        SetOptions(merge: true),
      );
      _userData?['currencyRegion'] = 'se';
      return;
    }

    final device = await PaymentService.resolveDeviceCountryForPricing();
    if (device != null) {
      PaymentService.resolveDeviceCountry();
    } else {
      await PaymentService.resolveDeviceCountry();
    }
    if (!mounted) return;

    final resolved = resolveCurrencyRegionForUser(
      locale: locale,
      storedRegion: _currencyRegion,
      deviceCountryCode: PaymentService.cachedGpsVerifiedCountryCode,
      paymentCountryCode: _userData?['paymentCountryCode'] as String?,
      role: role,
    );

    final locked = gpsLockedCurrencyRegion(
      PaymentService.cachedGpsVerifiedCountryCode ?? '',
      locale.languageCode,
    );
    final previousRegion = _currencyRegion;
    final changed = previousRegion != resolved ||
        ref.read(currencyRegionProvider) != resolved;
    if (!changed) return;

    setState(() => _currencyRegion = resolved);
    ref.read(currencyRegionProvider.notifier).state = resolved;

    final storedInProfile =
        CurrencyRegionParse.normalize(_userData?['currencyRegion']);
    final shouldPersist = persistIfAutoDetected ||
        locked != null ||
        storedInProfile != resolved;
    if (shouldPersist) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {'currencyRegion': resolved},
        SetOptions(merge: true),
      );
      _userData?['currencyRegion'] = resolved;
    }
  }

  FarmerShopSettings _farmerShopSettingsFromForm() {
    final minOrder = double.tryParse(_minOrderController.text.trim()) ?? 0;
    final maxDelivery =
        double.tryParse(_maxDeliveryController.text.trim()) ?? 0;
    return FarmerShopSettings(
      workingDays: List<String>.from(_selectedWorkingDays),
      workingHours: _workingHoursController.text.trim(),
      isAvailable: _isAvailable,
      minimumOrderAmount: minOrder,
      orderCurrency: _orderCurrency,
      offersPickup: _offersPickup,
      offersDelivery: _offersDelivery,
      maxDeliveryDistanceKm: maxDelivery,
      deliveryZone1MaxKm:
          double.tryParse(_zone1MaxController.text.trim()) ?? 5,
      deliveryZone1MinOrder:
          double.tryParse(_zone1MinController.text.trim()) ?? minOrder,
      deliveryZone2MaxKm:
          double.tryParse(_zone2MaxController.text.trim()) ?? 10,
      deliveryZone2MinOrder:
          double.tryParse(_zone2MinController.text.trim()) ??
              (minOrder > 0 ? minOrder + 10 : 30),
      pickupDays: List<String>.from(_selectedPickupDays),
      pickupHoursFrom: _pickupFromController.text.trim(),
      pickupHoursTo: _pickupToController.text.trim(),
      deliveryDays: List<String>.from(_selectedDeliveryDays),
      deliveryHoursFrom: _deliveryFromController.text.trim(),
      deliveryHoursTo: _deliveryToController.text.trim(),
      farmLat: _farmLat,
      farmLng: _farmLng,
    );
  }

  Future<void> _saveUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      final role = _userData?['role']?.toString();
      final address = _addressController.text.trim();

      if (_needsLocationFromAddress(role) &&
          address.isNotEmpty &&
          (_farmLat == null || _farmLng == null)) {
        final coords = await AddressGeocodingService().resolveCoordinates(
          address: address,
          lat: _farmLat,
          lng: _farmLng,
          userId: user.uid,
        );
        if (coords != null) {
          _farmLat = coords.lat;
          _farmLng = coords.lng;
        }
      }

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': address,
        'preferredLanguage': _selectedLocaleKey ??
            AppLocaleOption.fromLocale(context.locale)?.storageKey ??
            context.locale.languageCode,
        if (_currencyRegion != null && _currencyRegion!.isNotEmpty)
          'currencyRegion': _currencyRegion,
      };

      if (_needsLocationFromAddress(role) || isFarmerRole(role)) {
        payload.addAll(_farmerShopSettingsFromForm().toMap());
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      setState(() {
        _userData?['name'] = _nameController.text.trim();
        _userData?['phone'] = _phoneController.text.trim();
        _userData?['address'] = _addressController.text.trim();
        if (_needsLocationFromAddress(role) || isFarmerRole(role)) {
          _userData?.addAll(_farmerShopSettingsFromForm().toMap());
        }
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_saved'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common_error'.tr(namedArgs: {'error': '$e'}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _captureFarmLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('profile_gps_enable'.tr())),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('profile_location_permission'.tr())),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 8),
      );

      setState(() {
        _farmLat = position.latitude;
        _farmLng = position.longitude;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_farm_location_saved'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_gps_error'.tr(namedArgs: {'error': '$e'}))),
        );
      }
      await _geocodeAddressFallback();
    }
  }

  bool _needsLocationFromAddress(String? role) {
    final canonical = role?.trim().toLowerCase() ?? '';
    return canonical == 'veterinarian' || canonical == 'pharmacy';
  }

  Future<void> _geocodeAddressFallback() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final coords = await AddressGeocodingService().resolveCoordinates(
      address: address,
      userId: user?.uid,
    );
    if (coords == null || !mounted) return;

    setState(() {
      _farmLat = coords.lat;
      _farmLng = coords.lng;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('profile_farm_location_from_address'.tr()),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 500,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
      await _uploadImageToFirebase();
    }
  }

  Future<void> _uploadImageToFirebase() async {
    if (_image == null) return;
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profiles')
          .child('${user.uid}.jpg');

      await storageRef.putFile(
        _image!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'profileImageUrl': downloadUrl}, SetOptions(merge: true));

      setState(() => _userData?['profileImageUrl'] = downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_photo_saved'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_upload_error'.tr(namedArgs: {'error': '$e'}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: Text('scanner_gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.green),
              title: Text('scanner_camera'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).logoutAndClearCache();
    invalidateAuthSessionCache(ref);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  bool _showCurrencyRegionPicker(UserRole role) {
    return shouldShowCurrencyRegionPicker(
      context.locale,
      role,
      deviceCountryCode: PaymentService.cachedDeviceCountryCode,
    );
  }

  /// Normalizes legacy / lowercase locale keys to [supportedAppLocales] storage keys.
  String _normalizeLocaleStorageKey(String key) {
    final legacy = AppLocaleOption.normalizeLegacyStorageKey(key);
    if (legacy != key) return legacy;
    switch (key) {
      case 'sr':
        return 'sr_RS';
      case 'hr':
        return 'hr_HR';
      case 'bs':
        return 'bs';
      default:
        break;
    }
    final parts = key.split('_');
    if (parts.length == 2) {
      return '${parts[0]}_${parts[1].toUpperCase()}';
    }
    return key;
  }

  /// Prefer active [context.locale] when Firestore still holds the previous language.
  String _resolveInitialLocaleKey(String? storedLang) {
    final contextKey = _normalizeLocaleStorageKey(
      AppLocaleOption.fromLocale(context.locale)?.storageKey ??
          context.locale.languageCode,
    );
    if (storedLang == null || storedLang.isEmpty) {
      return _supportedLocaleStorageKeyOr(contextKey);
    }

    final storedKey = _normalizeLocaleStorageKey(storedLang);
    final storedOption = AppLocaleOption.fromStorageKey(storedKey);
    if (storedOption != null &&
        storedOption.languageCode != context.locale.languageCode) {
      return _supportedLocaleStorageKeyOr(contextKey);
    }
    return _supportedLocaleStorageKeyOr(storedKey);
  }

  String _supportedLocaleStorageKeyOr(String key) {
    final normalized = _normalizeLocaleStorageKey(key);
    if (supportedAppLocales.any((option) => option.storageKey == normalized)) {
      return normalized;
    }
    if (context.locale.languageCode == 'hr') return 'hr_HR';
    if (context.locale.languageCode == 'sr') return 'sr_RS';
    if (context.locale.languageCode == 'bs') return 'bs';
    return supportedAppLocales.first.storageKey;
  }

  AppLocaleOption? _selectedLanguageOption(String resolvedKey) {
    return AppLocaleOption.fromStorageKey(resolvedKey);
  }

  /// Ensures [DropdownButtonFormField] value always matches exactly one menu item.
  String _resolveProfileLocaleStorageKey() {
    if (_selectedLocaleKey != null && _selectedLocaleKey!.isNotEmpty) {
      final key = _normalizeLocaleStorageKey(_selectedLocaleKey!);
      if (supportedAppLocales.any((option) => option.storageKey == key)) {
        return key;
      }
    }

    final fromLocale = AppLocaleOption.fromLocale(context.locale)?.storageKey;
    if (fromLocale != null &&
        supportedAppLocales.any((option) => option.storageKey == fromLocale)) {
      return fromLocale;
    }

    final lang = context.locale.languageCode;
    final country = (context.locale.countryCode ?? '').toUpperCase();
    for (final option in supportedAppLocales) {
      final optionCountry = (option.countryCode ?? '').toUpperCase();
      if (option.languageCode == lang && optionCountry == country) {
        return option.storageKey;
      }
    }

    if (lang == 'sr') return 'sr_RS';
    if (lang == 'bs') return 'bs';
    if (lang == 'hr') return 'hr_HR';

    return supportedAppLocales.first.storageKey;
  }

  Future<String?> _resolveCurrencyRegionForLanguageOption(
    AppLocaleOption option,
  ) async {
    String? region = _currencyRegion;
    if (CurrencyService.isEuroLockedLanguage(option.locale)) {
      return 'eu';
    }
    if (CurrencyService.isUahLockedLanguage(option.locale)) {
      return 'eu';
    }
    if (CurrencyService.isRubLockedLanguage(option.locale)) {
      return 'eu';
    }
    if (CurrencyService.isInrLockedLanguage(option.locale)) {
      return 'eu';
    }
    if (CurrencyService.isIdrLockedLanguage(option.locale)) {
      return 'eu';
    }
    if (CurrencyService.isKesLockedLanguage(option.locale)) {
      return 'eu';
    }
    if (CurrencyService.isSarLockedLanguage(option.locale)) {
      return 'eu';
    }
    if (CurrencyService.isSwissChfLockedLanguage(option.locale)) {
      return 'eu';
    }
    if (CurrencyService.isCnyLockedLanguage(option.locale)) {
      return 'eu';
    }
    if (option.languageCode == 'bs') {
      return 'bih';
    }
    if (option.languageCode == 'sr') {
      if (region != 'rs' && region != 'bih') {
        final device = await PaymentService.resolveDeviceCountry();
        region = resolveCurrencyRegionForLocale(
          option.locale,
          deviceCountryCode: device.countryCode,
          paymentCountryCode: _userData?['paymentCountryCode'] as String?,
        );
      }
      return region == 'eu' ? 'rs' : region;
    }
    if (option.languageCode == 'sv') {
      if (AppUser.parseRole(_userData?['role']?.toString()) ==
          UserRole.veterinarian) {
        return 'se';
      }
      if (region != 'se' && region != 'eu') {
        final device = await PaymentService.resolveDeviceCountry();
        return resolveCurrencyRegionForUser(
          locale: option.locale,
          deviceCountryCode: device.countryCode,
          paymentCountryCode: _userData?['paymentCountryCode'] as String?,
          role: AppUser.parseRole(_userData?['role']?.toString()),
        );
      }
      return region;
    }
    if (option.languageCode == 'hr') {
      final device = await PaymentService.resolveDeviceCountry();
      return resolveCurrencyRegionForLocale(
        option.locale,
        storedRegion: region,
        deviceCountryCode: device.countryCode,
        paymentCountryCode: _userData?['paymentCountryCode'] as String?,
      );
    }
    return 'eu';
  }

  /// Keeps currency-region dropdown value inside its visible [items] list.
  String _resolveCurrencyRegionDropdownValue(UserRole role) {
    final allowed = allowedCurrencyRegionsForPicker(
      context.locale,
      deviceCountryCode: PaymentService.cachedDeviceCountryCode,
      role: role,
    );
    if (allowed.isEmpty) return 'eu';
    final raw = _effectiveCurrencyRegion(role) ?? 'eu';
    if (allowed.contains(raw)) return raw;
    return allowed.first;
  }

  String _currencyRegionLabel(String regionCode) {
    final region = CurrencyRegionParse.normalize(regionCode) ?? 'eu';
    switch (region) {
      case 'bih':
        return 'region_bih'.tr();
      case 'rs':
        return 'region_serbia'.tr();
      case 'se':
        return 'region_sweden'.tr();
      case 'eu':
      default:
        return 'region_eu'.tr();
    }
  }

  String? _effectiveCurrencyRegion(UserRole role) {
    return resolveCurrencyRegionForUser(
      locale: context.locale,
      storedRegion: _currencyRegion,
      deviceCountryCode: PaymentService.cachedDeviceCountryCode,
      paymentCountryCode: _userData?['paymentCountryCode'] as String?,
      role: role,
    );
  }

  String _currencyDisplayLabel(CurrencyInfo currency) {
    final translated = 'selected_currency'.tr();
    if (translated != 'selected_currency') return translated;

    switch (currency.code) {
      case CurrencyService.eur:
        return 'Euro - EUR (€)';
      case CurrencyService.sek:
        return 'Svenska kronor - SEK (kr)';
      case CurrencyService.uah:
        return 'Гривня - UAH (₴)';
      case CurrencyService.rub:
        return 'Рубль - RUB (₽)';
      case CurrencyService.inr:
        return 'भारतीय रुपया - INR (₹)';
      case CurrencyService.idr:
        return 'Rupiah Indonesia - IDR (Rp)';
      case CurrencyService.kes:
        return 'Shilingi ya Kenya - KES (KSh)';
      case CurrencyService.chf:
        return 'Schweizer Franken - CHF';
      case CurrencyService.sar:
        return 'الريال السعودي - SAR (ر.س)';
      case CurrencyService.aed:
        return 'درهم إماراتي - AED (د.إ)';
      case CurrencyService.egp:
        return 'جنيه مصري - EGP (ج.م)';
      case CurrencyService.mad:
        return 'درهم مغربي - MAD (د.م.)';
      case CurrencyService.qar:
        return 'ريال قطري - QAR (ر.ق)';
      case CurrencyService.jod:
        return 'دينار أردني - JOD (د.أ)';
      case CurrencyService.cny:
        return 'CNY (¥)';
      case CurrencyService.rsd:
        return 'RSD';
      case CurrencyService.bam:
      default:
        return 'KM - BAM';
    }
  }

  Future<void> _onLanguageChanged(String? storageKey) async {
    if (storageKey == null) return;
    final option = AppLocaleOption.fromStorageKey(storageKey);
    if (option == null) return;

    final normalizedKey = _normalizeLocaleStorageKey(storageKey);

    // 1) Value + zastava u dropdownu — odmah, prije setLocale rebuilda.
    setState(() => _selectedLocaleKey = normalizedKey);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'preferredLanguage': normalizedKey},
        SetOptions(merge: true),
      );
      _userData?['preferredLanguage'] = normalizedKey;
    }
    if (!mounted) return;

    // 2) Jezik odmah — prije GPS await-a za valutu.
    await context.setLocale(option.locale);
    if (!mounted) return;

    // 3) Valuta/regija (može čekati GPS).
    final region = await _resolveCurrencyRegionForLanguageOption(option);
    if (!mounted) return;

    ref.read(currencyRegionProvider.notifier).state = region;
    setState(() => _currencyRegion = region);

    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'currencyRegion': region},
        SetOptions(merge: true),
      );
      _userData?['currencyRegion'] = region;
    }
  }

  Future<void> _onCurrencyRegionChanged(String? region) async {
    if (region == null) return;
    setState(() => _currencyRegion = region);
    ref.read(currencyRegionProvider.notifier).state = region;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'currencyRegion': region},
        SetOptions(merge: true),
      );
    }
  }

  Widget _languageDropdownLabel(AppLocaleOption option) {
    return Row(
      children: [
        Text(option.flagEmoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            option.localizedLabel(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSettingsCard(UserRole role) {
    final resolvedKey = _resolveProfileLocaleStorageKey();
    final selectedOption = _selectedLanguageOption(resolvedKey);
    final currency = CurrencyService().resolve(
      context.locale,
      currencyRegion: _effectiveCurrencyRegion(role),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.language, color: Colors.green[800], size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'profile_language'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.green[900],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _guideLanguageKey,
              child: DropdownButtonFormField<String>(
                key: ValueKey('profile_lang_dropdown_$resolvedKey'),
                isExpanded: true,
                value: resolvedKey,
                decoration: InputDecoration(
                  labelText: 'profile_language'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Text(
                      selectedOption?.flagEmoji ?? '🌐',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  filled: true,
                  fillColor: Colors.green[50],
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                selectedItemBuilder: (context) {
                  return supportedAppLocales
                      .map(
                        (option) => Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _languageDropdownLabel(option),
                        ),
                      )
                      .toList();
                },
                items: supportedAppLocales
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.storageKey,
                        child: _languageDropdownLabel(option),
                      ),
                    )
                    .toList(),
                onChanged: _onLanguageChanged,
              ),
            ),
            if (_showCurrencyRegionPicker(role)) ...[
              const SizedBox(height: 10),
              KeyedSubtree(
                key: _guideCurrencyKey,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _resolveCurrencyRegionDropdownValue(role),
                  decoration: InputDecoration(
                    labelText: 'profile_currency_region'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon:
                        const Icon(Icons.payments_outlined, size: 22),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    for (final regionCode in allowedCurrencyRegionsForPicker(
                      context.locale,
                      deviceCountryCode:
                          PaymentService.cachedDeviceCountryCode,
                      role: role,
                    ))
                      DropdownMenuItem(
                        value: regionCode,
                        child: Text(
                          _currencyRegionLabel(regionCode),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _onCurrencyRegionChanged,
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              KeyedSubtree(
                key: _guideCurrencyKey,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _currencyDisplayLabel(currency),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green[900],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getRoleLabel(String? role) {
    final canonical = AppUser.normalizeRoleAlias(role);
    switch (canonical) {
      case 'buyer':
        return 'role_buyer'.tr();
      case 'hobby_farmer':
        return 'role_hobby_farmer'.tr();
      case 'professional_farmer':
      case 'farmer':
        return 'role_professional_farmer'.tr();
      case 'veterinarian':
        return 'role_veterinarian'.tr();
      case 'pharmacy':
        return 'role_company'.tr();
      case 'services':
        return 'services'.tr();
      case 'admin':
        return 'Admin';
      default:
        return canonical.isEmpty ? '...' : canonical;
    }
  }

  IconData? _getRoleIcon(String? role) {
    final canonical = AppUser.normalizeRoleAlias(role);
    switch (canonical) {
      case 'buyer':
        return Icons.shopping_cart_outlined;
      case 'hobby_farmer':
        return Icons.eco_outlined;
      case 'professional_farmer':
      case 'farmer':
        return Icons.agriculture;
      case 'veterinarian':
        return Icons.medical_services_outlined;
      case 'pharmacy':
        return Icons.storefront_outlined;
      case 'services':
        return Icons.build_outlined;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return null;
    }
  }

  Color _getRoleColor(String? role) {
    final canonical = AppUser.normalizeRoleAlias(role);
    switch (canonical) {
      case 'hobby_farmer':
        return Colors.lightGreen;
      case 'professional_farmer':
      case 'farmer':
        return Colors.orange;
      case 'veterinarian':
        return Colors.teal;
      case 'pharmacy':
        return Colors.deepPurple;
      case 'services':
        return Colors.blue;
      case 'admin':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final appUser = ref.watch(userDocProvider).valueOrNull;
    final liveRole = ref.watch(firestoreUserRoleProvider).valueOrNull;
    final effectiveRole = ref.watch(effectiveUserRoleProvider);
    final profileImageUrl = _userData?['profileImageUrl'];
    final resolvedFromData = _userData != null
        ? AppUser.resolveRoleCanonical(_userData!)
        : '';
    final role = ref.watch(adminPremiumBypassProvider)
        ? AppUser.roleToFirestore(effectiveRole)
        : (liveRole ??
            appUser?.roleFirestore ??
            (resolvedFromData.isNotEmpty ? resolvedFromData : ''));
    final parsedRole = effectiveRole;
    _syncProfileGuideSuppression(
      role: role,
      userData: _userData,
      parsedRole: parsedRole,
    );
    final profileGuideEnabled = _profileGuideEnabled(
      role: role,
      userData: _userData,
      parsedRole: parsedRole,
    );
    final profileGuideSteps = _guideStepsForRole(
      role: role,
      userData: _userData,
      parsedRole: parsedRole,
    );
    final isAdmin = appUser?.isAdminUser ??
        parsedRole == UserRole.admin ||
        AppUser.normalizeRoleAlias(liveRole) == 'admin';
    final shopSettings = FarmerShopSettings.fromMap(_userData ?? {});
    final isFarmer = isFarmerRole(role);
    final roleLabel = role.isEmpty
        ? '...'
        : _getRoleLabel(role);
    ref.listen<AsyncValue<String?>>(firestoreUserRoleProvider, (previous, next) {
      final nextRole = next.valueOrNull;
      if (nextRole == null || nextRole.isEmpty || !mounted) return;
      final cachedRole =
          AppUser.normalizeRoleAlias(_userData?['role']?.toString());
      if (cachedRole != nextRole) {
        final updatedData = {
          ...?_userData,
          'role': nextRole,
        };
        final parsedRole = AppUser.parseRole(nextRole);
        _syncProfileGuideSuppression(
          role: nextRole,
          userData: updatedData,
          parsedRole: parsedRole,
        );
        setState(() {
          _userData = updatedData;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTabIndex == 0
              ? 'profile_title'.tr()
              : 'profile_tab_gallery'.tr(),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        bottom: _userData == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(96),
                child: KeyedSubtree(
                  key: _guideTabsKey,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 14,
                    ),
                    color: Colors.green[700],
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: [
                        Tab(text: 'profile_title'.tr()),
                        Tab(text: 'profile_tab_gallery'.tr()),
                      ],
                    ),
                  ),
                ),
              ),
        actions: [
          FarmerHelperIconButton(
            enabled: profileGuideEnabled && !_profileGuideTourSuppressed,
            guideSteps: profileGuideSteps,
          ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'profile_edit'.tr(),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'cart_cancel'.tr(),
              onPressed: () {
                setState(() => _isEditing = false);
                _loadUserData();
              },
            ),
        ],
      ),
      body: _profileLoadErrorObject != null
          ? FirestoreErrorPanel(
              error: _profileLoadErrorObject!,
              onRetry: _loadUserData,
            )
          : _isLoadingProfile || _userData == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileInfoTab(
                  user: user,
                  parsedRole: parsedRole,
                  isAdmin: isAdmin,
                  profileImageUrl: profileImageUrl,
                  role: role,
                  roleLabel: roleLabel,
                  shopSettings: shopSettings,
                  isFarmer: isFarmer,
                ),
                UserCommunityGalleryGrid(userId: user!.uid),
              ],
            ),
    );
  }

  Widget _buildProfileInfoTab({
    required User? user,
    required UserRole parsedRole,
    required bool isAdmin,
    required String? profileImageUrl,
    required dynamic role,
    required String roleLabel,
    required FarmerShopSettings shopSettings,
    required bool isFarmer,
  }) {
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),

          KeyedSubtree(
            key: _guideFarmerIdentityKey,
            child: Column(
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.green[100],
                        backgroundImage: _image != null
                            ? FileImage(_image!) as ImageProvider
                            : (profileImageUrl != null
                                ? NetworkImage(profileImageUrl)
                                : null),
                        child: (_image == null && profileImageUrl == null)
                            ? Icon(Icons.person,
                                size: 60, color: Colors.green[700])
                            : (_isUploading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : null),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploading
                              ? null
                              : () => _showImagePicker(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[700],
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _userData?['name'] ?? user?.email ?? 'common_user'.tr(),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isFarmer && user != null) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: FarmerFollowerCountBadge(farmerId: user.uid),
                  ),
                ],
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getRoleColor(role).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_getRoleIcon(role) != null) ...[
                          Icon(
                            _getRoleIcon(role),
                            size: 16,
                            color: _getRoleColor(role),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          roleLabel,
                          style: TextStyle(
                            color: _getRoleColor(role),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              user?.email ?? '',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 16),
            const AdminRoleSwitcher(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen(),
                  ),
                ),
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Admin Panel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 30),
          const Divider(),
          _buildLanguageSettingsCard(parsedRole),
          const SizedBox(height: 16),
          const Divider(),

          // EDIT MODE
          if (_isEditing) ...[
            Text('profile_edit_section'.tr(),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'full_name'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _guidePhoneKey,
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'phone'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _guideAddressKey,
              child: TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'address'.tr(),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ProfilePaymentMethodsTile(guideKey: _guidePaypalKey),
            const SizedBox(height: 12),
            if (isFarmer) ...[
              Text(
                'profile_shop_section'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: _guideShopHoursKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('profile_available_orders'.tr()),
                      subtitle: Text(_isAvailable
                          ? 'profile_available'.tr()
                          : 'profile_unavailable'.tr()),
                      value: _isAvailable,
                      activeColor: Colors.green[700],
                      onChanged: (value) =>
                          setState(() => _isAvailable = value),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'profile_working_days'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FarmerShopSettings.allWeekDays.map((day) {
                        final selected = _selectedWorkingDays.contains(day);
                        return FilterChip(
                          label: Text(WeekdayLocalization.label(day)),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedWorkingDays.add(day);
                              } else {
                                _selectedWorkingDays.remove(day);
                              }
                            });
                          },
                          selectedColor: Colors.green[100],
                          checkmarkColor: Colors.green[800],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _workingHoursController,
                      decoration: InputDecoration(
                        labelText: 'profile_working_hours'.tr(),
                        hintText: 'profile_working_hours_hint'.tr(),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.access_time),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: _guideMinOrderKey,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _minOrderController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'profile_min_order'.tr(),
                          hintText: 'npr. 25',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.local_shipping_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _orderCurrency,
                        items: const [
                          DropdownMenuItem(value: 'KM', child: Text('KM')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _orderCurrency = value);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'profile_currency'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'profile_delivery_options'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('cart_pickup'.tr()),
                value: _offersPickup,
                activeColor: Colors.green[700],
                onChanged: (value) => setState(() => _offersPickup = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('cart_delivery'.tr()),
                value: _offersDelivery,
                activeColor: Colors.green[700],
                onChanged: (value) => setState(() => _offersDelivery = value),
              ),
              if (_offersDelivery) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _maxDeliveryController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'profile_max_delivery_km'.tr(),
                    hintText: 'npr. 15',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.map_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                KeyedSubtree(
                  key: _guideDeliveryZonesKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'profile_delivery_zones'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _zone1MaxController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'profile_zone1_km'.tr(),
                                hintText: '5',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _zone1MinController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'profile_min_order_short'.tr(),
                                hintText: '20',
                                suffixText: _orderCurrency,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _zone2MaxController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'profile_zone2_km'.tr(),
                                hintText: '10',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _zone2MinController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'profile_min_order_short'.tr(),
                                hintText: '30',
                                suffixText: _orderCurrency,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                KeyedSubtree(
                  key: _guideDeliveryInfoKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'profile_delivery_schedule'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: FarmerShopSettings.allWeekDays.map((day) {
                          final selected = _selectedDeliveryDays.contains(day);
                          return FilterChip(
                            label: Text(WeekdayLocalization.label(day)),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedDeliveryDays.add(day);
                                } else {
                                  _selectedDeliveryDays.remove(day);
                                }
                              });
                            },
                            selectedColor: Colors.green[100],
                            checkmarkColor: Colors.green[800],
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _deliveryFromController,
                              decoration: InputDecoration(
                                labelText: 'profile_delivery_from'.tr(),
                                hintText: '08:00',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _deliveryToController,
                              decoration: InputDecoration(
                                labelText: 'profile_delivery_to'.tr(),
                                hintText: '17:00',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _captureFarmLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    _farmLat != null && _farmLng != null
                        ? 'profile_farm_location_set'.tr(namedArgs: {
                            'lat': _farmLat!.toStringAsFixed(4),
                            'lng': _farmLng!.toStringAsFixed(4),
                          })
                        : 'profile_set_farm_location'.tr(),
                  ),
                ),
              ],
              if (_offersPickup) ...[
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: _guidePickupKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'profile_pickup_schedule'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: FarmerShopSettings.allWeekDays.map((day) {
                          final selected = _selectedPickupDays.contains(day);
                          return FilterChip(
                            label: Text(WeekdayLocalization.label(day)),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedPickupDays.add(day);
                                } else {
                                  _selectedPickupDays.remove(day);
                                }
                              });
                            },
                            selectedColor: Colors.green[100],
                            checkmarkColor: Colors.green[800],
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pickupFromController,
                              decoration: InputDecoration(
                                labelText: 'profile_pickup_from'.tr(),
                                hintText: '08:00',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _pickupToController,
                              decoration: InputDecoration(
                                labelText: 'profile_pickup_to'.tr(),
                                hintText: '17:00',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
            ElevatedButton(
              onPressed: _isUploading ? null : _saveUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isUploading
                  ? const CircularProgressIndicator(
                  color: Colors.white)
                  : Text('profile_save'.tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            const Divider(),
          ] else ...[
            // PRIKAZ PODATAKA
            KeyedSubtree(
              key: _guidePhoneKey,
              child: _infoTile(Icons.phone_outlined, 'phone'.tr(),
                  _userData?['phone'] ?? 'profile_not_set'.tr()),
            ),
            KeyedSubtree(
              key: _guideAddressKey,
              child: _infoTile(Icons.location_on_outlined, 'address'.tr(),
                  _userData?['address'] ?? 'profile_not_set'.tr()),
            ),

            ProfilePaymentMethodsTile(guideKey: _guidePaypalKey),
            const SizedBox(height: 16),

            if (isFarmerRole(role) || isProfessionalFarmer(role)) ...[
              KeyedSubtree(
                key: _guideLandKey,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.green[200]!),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green[100],
                      child:
                          Icon(Icons.satellite_alt, color: Colors.green[800]),
                    ),
                    title: Text(
                      farmerGuideTr(context, 'land_profile_title'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      farmerGuideTr(context, 'land_profile_subtitle'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LandMeasurementScreen(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (UpcomingProductHelper.isCompanyRole(role)) ...[
              const CompanyCatalogProfileTile(),
              const SizedBox(height: 12),
              const CompanyCatalogPdfProfileTile(),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.deepPurple.shade200),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade50,
                    child: Icon(
                      Icons.bar_chart_rounded,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  title: Text(
                    'company_b2b_analytics_title'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'company_b2b_analytics_subtitle'.tr(),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => CompanyPremiumGateDialog.showForCompany(
                    context,
                    ref,
                    feature: PremiumFeature.marketplaceBoost,
                    onUnlocked: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CompanyMarketAnalyticsScreen(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (isFarmerRole(role)) ...[
              KeyedSubtree(
                key: _guideFarmKey,
                child: _infoTile(
                  Icons.agriculture_outlined,
                  'profile_farm_number'.tr(),
                  _userData?['extraInfo'] ?? 'profile_not_set'.tr(),
                ),
              ),
              KeyedSubtree(
                key: _guideShopHoursKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _infoTile(
                      shopSettings.isAvailable
                          ? Icons.check_circle
                          : Icons.cancel,
                      'profile_availability'.tr(),
                      FarmerShopLocalization.availability(
                          shopSettings.isAvailable),
                    ),
                    _infoTile(
                      Icons.calendar_today_outlined,
                      'profile_working_days'.tr(),
                      FarmerShopLocalization.workingDays(shopSettings),
                    ),
                    if (shopSettings.workingHours.isNotEmpty)
                      _infoTile(
                        Icons.access_time,
                        'profile_working_hours'.tr(),
                        shopSettings.workingHours,
                      ),
                  ],
                ),
              ),
              KeyedSubtree(
                key: _guideMinOrderKey,
                child: _infoTile(
                  Icons.local_shipping_outlined,
                  'profile_min_order'.tr(),
                  FarmerShopLocalization.minimumOrder(shopSettings),
                ),
              ),
              if (shopSettings.offersPickup)
                KeyedSubtree(
                  key: _guidePickupKey,
                  child: _infoTile(
                    Icons.store_mall_directory_outlined,
                    'cart_pickup'.tr(),
                    FarmerShopLocalization.pickupDays(shopSettings),
                  ),
                ),
              if (shopSettings.offersDelivery) ...[
                KeyedSubtree(
                  key: _guideDeliveryInfoKey,
                  child: _infoTile(
                    Icons.local_shipping_outlined,
                    'cart_delivery'.tr(),
                    FarmerShopLocalization.deliveryDays(shopSettings),
                  ),
                ),
                KeyedSubtree(
                  key: _guideDeliveryZonesKey,
                  child: _infoTile(
                    Icons.map_outlined,
                    'profile_delivery_zones'.tr(),
                    FarmerShopLocalization.deliveryZones(shopSettings),
                  ),
                ),
              ],
            ],
            if (role == 'veterinarian' || role == 'pharmacy' || role == 'services')
              _infoTile(
                  Icons.business_outlined,
                  role == 'veterinarian'
                      ? 'veterinary_license'.tr()
                      : 'profile_reg_number'.tr(),
                  role == 'veterinarian'
                      ? (_userData?['veterinaryLicense'] ??
                          _userData?['extraInfo'] ??
                          'profile_not_set'.tr())
                      : (_userData?['companyRegistrationNumber'] ??
                          _userData?['extraInfo'] ??
                          'profile_not_set'.tr())),
            if (parsedRole == UserRole.veterinarian) ...[
              const SizedBox(height: 12),
              _buildVetProfileActions(context),
            ],
            const Divider(),
          ],

          if (parsedRole != UserRole.veterinarian &&
              !UpcomingProductHelper.isCompanyRole(role))
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.green[200]!),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Icon(Icons.pets, color: Colors.green[800]),
                ),
                title: Text(
                  'animals_title'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('animals_profile_subtitle'.tr()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyAnimalsScreen(),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          const ProfileSubscriptionCard(),
          const SizedBox(height: 12),
          const RolesSubscriptionPdfProfileTile(),
          const SizedBox(height: 12),
          const BetaTestGuideProfileTile(),
          const SizedBox(height: 12),
          const ProfileLegalTermsTile(),
          const SizedBox(height: 12),
          const ProfilePrivacyPolicyTile(),
          const SizedBox(height: 12),
          const ProfileDeleteAccountTile(),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Build ${AppVersion.label}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),

          // ODJAVA
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text('logout'.tr(),
                style: const TextStyle(color: Colors.red)),
            onTap: _signOut,
          ),
        ],
      );
  }

  Widget _buildVetProfileActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVetActionButton(
          context,
          icon: Icons.medical_services,
          labelKey: 'vet_patient_records',
          subtitleKey: 'vet_patient_records_btn_desc',
          color: Colors.teal.shade700,
          onTap: () => PremiumGateDialog.showForVeterinarian(
            context,
            ref,
            onUnlocked: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VeterinarianAnimalsHubScreen(
                  initialTab: VeterinarianAnimalsTab.digitalIntake,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildVetActionButton(
          context,
          icon: Icons.pets,
          labelKey: 'vet_my_pets',
          subtitleKey: 'vet_my_pets_btn_desc',
          color: Colors.green.shade700,
          onTap: () => PremiumGateDialog.showForVeterinarian(
            context,
            ref,
            onUnlocked: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyAnimalsScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVetActionButton(
    BuildContext context, {
    required IconData icon,
    required String labelKey,
    required String subtitleKey,
    required Color color,
    required VoidCallback onTap,
  }) {
    final access = ref.watch(premiumAccessProvider);
    final isLocked = !access.canUse(PremiumFeature.digitalMedicalIntake);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: isLocked ? 2 : 4,
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farmerGuideTr(context, labelKey),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    farmerGuideTr(context, subtitleKey),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isLocked ? Icons.lock_outline : Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.green[700]),
      title: Text(label,
          style: const TextStyle(fontSize: 13, color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }
}