import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/revenuecat_config.dart';
import '../../models/cart_item.dart';
import '../../models/farmer_shop_settings.dart';
import '../../models/payment_method.dart';
import '../../models/payment_result.dart';
import '../../models/premium_access.dart';
import '../../providers/locale_settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../repositories/farmer_shop_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/product_repository.dart';
import '../../utils/farmer_shop_localization.dart';
import '../../utils/localized_title.dart';
import '../../models/product_units.dart';
import '../../widgets/product_price_text.dart';
import '../../widgets/translated_text.dart';
import '../../models/screen_guide_step.dart';
import '../../widgets/farmer_helper_button.dart';
import '../../widgets/premium_gate.dart';
import '../../services/delivery_service.dart';
import '../../services/currency_service.dart';
import '../../services/payment_service.dart';
import '../../services/peer_marketplace_payment_service.dart';
import '../../config/marketplace_payment_config.dart';
import '../../widgets/quantity_stepper.dart';
import 'cart_provider.dart';



class CartScreen extends ConsumerStatefulWidget {

  const CartScreen({super.key});



  @override

  ConsumerState<CartScreen> createState() => _CartScreenState();

}



class _CartScreenState extends ConsumerState<CartScreen> {

  List<CartSellerIssue> _issues = [];

  List<CartSellerIssue> _deliveryIssues = [];

  Map<String, FarmerShopSettings> _sellerSettings = {};

  Map<String, DeliveryOption> _deliveryBySeller = {};

  Position? _buyerPosition;

  bool _isValidating = false;

  bool _isCheckingDelivery = false;

  String _paymentMethod = 'cash';

  String _paymentLabel(
    String key, {
    required String hr,
    required String de,
    required String en,
  }) {
    final translated = key.tr();
    if (translated != key) return translated;
    final language = context.locale.languageCode;
    if (language == 'de') return de;
    if (language == 'en') return en;
    return hr;
  }

  final GlobalKey _guidePaymentKey = GlobalKey();
  final GlobalKey _guideDeliveryKey = GlobalKey();
  final GlobalKey _guideCheckoutKey = GlobalKey();

  List<ScreenGuideStep> get _guideSteps => [
        ScreenGuideStep(
          targetKey: _guidePaymentKey,
          titleKey: 'guide_cart_payment_title',
          bodyKey: 'guide_cart_payment_body',
        ),
        ScreenGuideStep(
          targetKey: _guideDeliveryKey,
          titleKey: 'guide_cart_delivery_title',
          bodyKey: 'guide_cart_delivery_body',
        ),
        ScreenGuideStep(
          targetKey: _guideCheckoutKey,
          titleKey: 'guide_cart_checkout_title',
          bodyKey: 'guide_cart_checkout_body',
        ),
      ];

  final DeliveryService _deliveryService = DeliveryService();



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _validateCart());

  }



  Map<String, List<CartItem>> _groupBySeller(List<CartItem> items) {

    final grouped = <String, List<CartItem>>{};

    for (final item in items) {

      grouped.putIfAbsent(item.sellerId, () => []).add(item);

    }

    return grouped;

  }



  double _sellerSubtotal(String sellerId, List<CartItem> items) {

    return items

        .where((item) => item.sellerId == sellerId)

        .fold(0.0, (sum, item) => sum + item.lineTotal);

  }



  double? _distanceKmForSeller(FarmerShopSettings settings) {

    if (_buyerPosition == null || !settings.hasFarmLocation) return null;

    return _deliveryService.distanceKm(

      fromLat: settings.farmLat!,

      fromLng: settings.farmLng!,

      toLat: _buyerPosition!.latitude,

      toLng: _buyerPosition!.longitude,

    );

  }



  bool _sellerMeetsDeliveryMinimum(

    String sellerId,

    List<CartItem> items,

    FarmerShopSettings settings,

  ) {

    final total = _sellerSubtotal(sellerId, items);

    return settings.meetsMinimum(

      total,

      option: DeliveryOption.delivery,

      distanceKm: _distanceKmForSeller(settings),

    );

  }



  double _remainingForDeliveryMinimum(

    String sellerId,

    List<CartItem> items,

    FarmerShopSettings settings,

  ) {

    final total = _sellerSubtotal(sellerId, items);

    final min = settings.minimumForDeliveryDistance(_distanceKmForSeller(settings));

    if (min.isInfinite) return 0;

    return (min - total).clamp(0, double.infinity);

  }



  bool _hasMinOrderBlock(List<CartItem> items) {

    final grouped = _groupBySeller(items);

    for (final entry in grouped.entries) {

      final sellerId = entry.key;

      final settings =

          _sellerSettings[sellerId] ?? const FarmerShopSettings();

      final selected =

          _deliveryBySeller[sellerId] ?? settings.defaultDeliveryOption;

      if (selected != DeliveryOption.delivery) continue;

      if (!_sellerMeetsDeliveryMinimum(sellerId, items, settings)) {

        return true;

      }

    }

    return false;

  }



  bool _isMinOrderIssue(CartSellerIssue issue, List<CartItem> items) {

    final settings =

        _sellerSettings[issue.sellerId] ?? const FarmerShopSettings();

    final selected = _deliveryBySeller[issue.sellerId] ??

        settings.defaultDeliveryOption;

    if (selected != DeliveryOption.delivery) return false;

    return !_sellerMeetsDeliveryMinimum(issue.sellerId, items, settings);

  }



  Widget _buildDeliveryOptionTile({

    required DeliveryOption option,

    required DeliveryOption selected,

    required String title,

    required bool isApproved,

    required VoidCallback onTap,

    String? hint,

  }) {

    final isSelected = selected == option;

    final approvedColor = Colors.green[700]!;

    final neutralColor = Colors.grey[400]!;

    final activeColor = isSelected

        ? (isApproved ? approvedColor : neutralColor)

        : Colors.grey[600]!;



    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(10),

        child: Container(

          width: double.infinity,

          margin: const EdgeInsets.only(bottom: 6),

          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

          decoration: BoxDecoration(

            color: isSelected

                ? (isApproved

                    ? Colors.green.withValues(alpha: 0.08)

                    : Colors.grey.withValues(alpha: 0.08))

                : Colors.white,

            borderRadius: BorderRadius.circular(10),

            border: Border.all(

              color: isSelected ? activeColor : Colors.grey[300]!,

              width: isSelected ? 2 : 1,

            ),

          ),

          child: Row(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Icon(

                isSelected

                    ? Icons.radio_button_checked

                    : Icons.radio_button_off,

                color: isSelected ? activeColor : Colors.grey[500],

                size: 22,

              ),

              const SizedBox(width: 10),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style: TextStyle(

                        fontWeight:

                            isSelected ? FontWeight.w600 : FontWeight.w500,

                        fontSize: 14,

                        color: Colors.grey[900],

                      ),

                    ),

                    if (hint != null && hint.isNotEmpty) ...[

                      const SizedBox(height: 4),

                      Text(

                        hint,

                        style: TextStyle(

                          fontSize: 12,

                          color: isSelected && !isApproved

                              ? Colors.grey[700]

                              : Colors.green[800],

                          fontWeight: FontWeight.w500,

                        ),

                      ),

                    ],

                  ],

                ),

              ),

              if (isSelected)

                Icon(

                  isApproved ? Icons.check_circle : Icons.hourglass_bottom,

                  color: activeColor,

                  size: 20,

                ),

            ],

          ),

        ),

      ),

    );

  }



  Future<void> _loadSellerSettings(List<CartItem> items) async {

    if (items.isEmpty) {

      if (mounted) {

        setState(() {

          _sellerSettings = {};

          _deliveryBySeller = {};

        });

      }

      return;

    }



    final grouped = _groupBySeller(items);

    final settings = await ref

        .read(farmerShopRepositoryProvider)

        .getSettingsForSellers(grouped.keys);



    final deliveryChoices = Map<String, DeliveryOption>.from(_deliveryBySeller);

    for (final sellerId in grouped.keys) {

      final shopSettings = settings[sellerId] ?? const FarmerShopSettings();

      deliveryChoices.putIfAbsent(

        sellerId,

        () => shopSettings.defaultDeliveryOption,

      );



      final current = deliveryChoices[sellerId]!;

      if (current == DeliveryOption.pickup && !shopSettings.offersPickup) {

        deliveryChoices[sellerId] = shopSettings.defaultDeliveryOption;

      }

      if (current == DeliveryOption.delivery && !shopSettings.offersDelivery) {

        deliveryChoices[sellerId] = shopSettings.defaultDeliveryOption;

      }

    }



    deliveryChoices.removeWhere((sellerId, _) => !grouped.containsKey(sellerId));



    if (mounted) {

      setState(() {

        _sellerSettings = settings;

        _deliveryBySeller = deliveryChoices;

      });

    }

  }



  Future<void> _validateDelivery(List<CartItem> items) async {

    if (items.isEmpty) {

      if (mounted) setState(() => _deliveryIssues = []);

      return;

    }



    setState(() => _isCheckingDelivery = true);



    final issues = await ref.read(farmerShopRepositoryProvider).validateDeliveryChoices(

          items: items,

          deliveryBySeller: _deliveryBySeller,

          buyerPosition: _buyerPosition,

        );



    if (mounted) {

      setState(() {

        _deliveryIssues = issues;

        _isCheckingDelivery = false;

      });

    }

  }



  Future<void> _validateCart() async {

    final items = ref.read(cartProvider);

    if (items.isEmpty) {

      if (mounted) {

        setState(() {

          _issues = [];

          _deliveryIssues = [];

          _sellerSettings = {};

          _deliveryBySeller = {};

        });

      }

      return;

    }



    setState(() => _isValidating = true);



    await _loadSellerSettings(items);



    final issues =
        await ref.read(farmerShopRepositoryProvider).validateCartItems(
              items: items,
              deliveryBySeller: _deliveryBySeller,
              buyerPosition: _buyerPosition,
            );



    if (mounted) {

      setState(() {

        _issues = issues;

        _isValidating = false;

      });

    }



    await _validateDelivery(items);

  }



  Future<void> _onDeliveryChanged(

    String sellerId,

    DeliveryOption option,

  ) async {

    setState(() {

      _deliveryBySeller[sellerId] = option;

    });



    if (option == DeliveryOption.delivery && _buyerPosition == null) {

      try {

        final serviceEnabled = await Geolocator.isLocationServiceEnabled();

        if (serviceEnabled) {

          var permission = await Geolocator.checkPermission();

          if (permission == LocationPermission.denied) {

            permission = await Geolocator.requestPermission();

          }

          if (permission == LocationPermission.whileInUse ||

              permission == LocationPermission.always) {

            _buyerPosition = await Geolocator.getCurrentPosition(

              desiredAccuracy: LocationAccuracy.low,

              timeLimit: const Duration(seconds: 8),

            );

          }

        }

      } catch (_) {}

    }



    await _validateCart();

  }



  Future<void> _refreshLocation() async {

    setState(() => _isCheckingDelivery = true);



    try {

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              content: Text('cart_gps_enable'.tr()),

            ),

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

            SnackBar(

              content: Text('cart_location_permission'.tr()),

            ),

          );

        }

        return;

      }



      _buyerPosition = await Geolocator.getCurrentPosition(

        desiredAccuracy: LocationAccuracy.low,

        timeLimit: const Duration(seconds: 8),

      );

    } finally {

      if (mounted) {

        await _validateDelivery(ref.read(cartProvider));

      }

    }

  }



  Future<void> _placeOrder() async {

    final items = ref.read(cartProvider);

    if (_hasMinOrderBlock(items)) return;

    final blockingIssues = [

      ..._issues.where((issue) => !_isMinOrderIssue(issue, items)),

      ..._deliveryIssues,

    ];

    if (blockingIssues.isNotEmpty) return;

    final access = ref.read(premiumAccessProvider);

    if (!canCheckoutCart(access: access, items: items)) {
      await PremiumGate.run(
        context,
        ref,
        feature: PremiumFeature.upcomingReservation,
        onUnlocked: () => _submitOrder(),
      );
      return;
    }

    await _submitOrder();
  }



  Future<void> _submitOrder() async {

    final stockCheck = await ref
        .read(cartProvider.notifier)
        .validateStockAgainstServer(ref.read(productRepositoryProvider));

    if (stockCheck.wasAdjusted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('cart_stock_insufficient'.tr()),
            backgroundColor: Colors.orange[800],
          ),
        );
      }
      return;
    }

    if (!stockCheck.canProceed) return;

    final items = ref.read(cartProvider);

    if (items.isEmpty) return;

    final issues =
        await ref.read(farmerShopRepositoryProvider).validateCartItems(
              items: items,
              deliveryBySeller: _deliveryBySeller,
              buyerPosition: _buyerPosition,
            );

    final deliveryIssues = await ref
        .read(farmerShopRepositoryProvider)
        .validateDeliveryChoices(
          items: items,
          deliveryBySeller: _deliveryBySeller,
          buyerPosition: _buyerPosition,
        );

    if (issues.isNotEmpty || deliveryIssues.isNotEmpty) {
      setState(() {
        _issues = issues;
        _deliveryIssues = deliveryIssues;
      });
      return;
    }

    final selectedMethod = CartPaymentMethod.fromValue(_paymentMethod);

    if (!isAllowedPaymentMethod(
      items: items,
      paymentMethod: _paymentMethod,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('peer_payment_upcoming_required'.tr()),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        setState(() => _paymentMethod =
            defaultPaymentMethodForCart(items).firestoreValue);
      }
      return;
    }

    final uniqueSellers = items.map((i) => i.sellerId).toSet();
    if (MarketplacePaymentConfig.peerToPeerOnly &&
        uniqueSellers.length > 1 &&
        selectedMethod != CartPaymentMethod.cash) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('peer_payment_multi_seller'.tr()),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    PaymentResult paymentResult;
    if (MarketplacePaymentConfig.peerToPeerOnly) {
      final converted = _cartConvertedTotal(items);
      final amountLabel =
          '${converted.displayAmount.toStringAsFixed(2)} ${converted.displayCurrency}';
      final peerService = PeerMarketplacePaymentService();
      final seller = await peerService.loadSellerDetails(items.first.sellerId);
      if (!mounted) return;
      final paymentOutcome = await peerService.confirmPeerPayment(
        context: context,
        method: selectedMethod,
        seller: seller,
        amountLabel: amountLabel,
      );
      if (!mounted || paymentOutcome == null) return;
      paymentResult = paymentOutcome;
    } else if (selectedMethod.requiresDigitalProcessing) {
      final converted = _cartConvertedTotal(items);
      final paymentOutcome = await ref.read(paymentServiceProvider).processPayment(
            context: context,
            method: selectedMethod,
            amount: converted.displayAmount,
            currency: converted.displayCurrency,
            sellerId: items.length == 1 ? items.first.sellerId : null,
          );
      if (!mounted || paymentOutcome == null) return;
      paymentResult = paymentOutcome;
    } else {
      paymentResult = PaymentResult.cashPending();
    }

    try {

      final orderRepo = ref.read(orderRepositoryProvider);

      final orderCount = await orderRepo.createOrdersFromCart(

        items: items,

        deliveryBySeller: _deliveryBySeller,

        paymentMethod: paymentResult.paymentMethod,

        paymentStatus: paymentResult.paymentStatus,

        transactionId: paymentResult.transactionId,

      );



      ref.read(cartProvider.notifier).clearCart();



      if (mounted) {

        showDialog(

          context: context,

          builder: (_) => AlertDialog(

            title: Text('cart_order_success_title'.tr()),

            content: Text(

              orderCount == 1

                  ? 'cart_order_success_one'.tr()

                  : 'cart_order_success_many'
                      .tr(namedArgs: {'count': '$orderCount'}),

            ),

            actions: [

              ElevatedButton(

                onPressed: () {

                  Navigator.pop(context);

                  Navigator.pop(context);

                },

                style: ElevatedButton.styleFrom(

                  backgroundColor: Colors.green[700],

                ),

                child: Text(

                  'ok'.tr(),

                  style: const TextStyle(color: Colors.white),

                ),

              ),

            ],

          ),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('common_error'.tr(namedArgs: {'error': '$e'}))),

        );

      }

    }

  }



  Widget _buildPaymentMethodSection(List<CartItem> cartItems) {
    final requiresDigitalPayment = cartRequiresDigitalPayment(cartItems);

    if (requiresDigitalPayment && _paymentMethod == 'cash') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _paymentMethod =
              CartPaymentMethod.directPaypal.firestoreValue);
        }
      });
    }

    return Container(
      key: _guidePaymentKey,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, color: Colors.green[800], size: 20),
              const SizedBox(width: 8),
              Text(
                _paymentLabel(
                  'cart_payment_method',
                  hr: 'Način plaćanja',
                  de: 'Zahlungsmethode',
                  en: 'Payment method',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.green[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (requiresDigitalPayment)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'peer_payment_upcoming_required'.tr(),
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              'peer_payment_disclaimer_short'.tr(),
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          if (!requiresDigitalPayment)
            _buildFixedPaymentCard(
              value: 'cash',
              label: _paymentLabel(
                'cart_payment_cash',
                hr: 'Gotovina pri preuzimanju / dostavi',
                de: 'Bar bei Abholung / Lieferung',
                en: 'Cash on pickup / delivery',
              ),
              icon: Icons.payments_outlined,
              color: Colors.green.shade700,
            ),
          if (!requiresDigitalPayment) const SizedBox(height: 8),
          _buildFixedPaymentCard(
            value: 'direct_paypal',
            label: 'peer_payment_option_paypal'.tr(),
            icon: Icons.account_balance_wallet,
            color: const Color(0xFF003087),
          ),
          const SizedBox(height: 8),
          _buildFixedPaymentCard(
            value: 'bank_transfer',
            label: 'peer_payment_option_bank'.tr(),
            icon: Icons.account_balance,
            color: Colors.teal.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildFixedPaymentCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _paymentMethod == value;

    return Card(
      elevation: isSelected ? 3 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
      child: ListTile(
        onTap: () => setState(() => _paymentMethod = value),
        leading: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? color : Colors.grey.shade500,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 15,
            color: Colors.grey.shade900,
          ),
        ),
        trailing: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildDeliverySection(List<CartItem> cartItems) {

    final grouped = _groupBySeller(cartItems);



    return Column(
      key: _guideDeliveryKey,
      crossAxisAlignment: CrossAxisAlignment.start,

      children: grouped.entries.map((entry) {

        final sellerId = entry.key;

        final sellerName = entry.value.first.sellerName;

        final settings =

            _sellerSettings[sellerId] ?? const FarmerShopSettings();

        final selected =

            _deliveryBySeller[sellerId] ?? settings.defaultDeliveryOption;

        final sellerSubtotal = _sellerSubtotal(sellerId, cartItems);

        final deliveryApproved =

            _sellerMeetsDeliveryMinimum(sellerId, cartItems, settings);

        final remaining = _remainingForDeliveryMinimum(

          sellerId,

          cartItems,

          settings,

        );

        final remainingHint = remaining > 0

            ? 'cart_delivery_min_remaining'.tr(namedArgs: {

                'amount': remaining.toStringAsFixed(2),

                'currency': settings.orderCurrency,

              })

            : null;



        return Container(

          width: double.infinity,

          margin: const EdgeInsets.only(bottom: 12),

          padding: const EdgeInsets.all(12),

          decoration: BoxDecoration(

            color: Colors.green[50],

            borderRadius: BorderRadius.circular(12),

            border: Border.all(color: Colors.green[200]!),

          ),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(

                children: [

                  Icon(Icons.local_shipping_outlined,

                      color: Colors.green[800], size: 20),

                  const SizedBox(width: 8),

                  Expanded(

                    child: Text(

                      'cart_delivery_section'
                          .tr(namedArgs: {'farmer': sellerName}),

                      style: TextStyle(

                        fontWeight: FontWeight.bold,

                        color: Colors.green[900],

                      ),

                    ),

                  ),

                ],

              ),

              const SizedBox(height: 10),

              if (settings.offersDelivery)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    FarmerShopLocalization.deliveryZones(settings),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              if (settings.offersPickup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${'cart_pickup'.tr()}: ${FarmerShopLocalization.pickupDays(settings)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              if (settings.offersDelivery)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${'cart_delivery'.tr()}: ${FarmerShopLocalization.deliveryDays(settings)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              if (settings.offersPickup)

                _buildDeliveryOptionTile(

                  option: DeliveryOption.pickup,

                  selected: selected,

                  title: 'cart_pickup'.tr(),

                  isApproved: true,

                  onTap: () => _onDeliveryChanged(sellerId, DeliveryOption.pickup),

                ),

              if (settings.offersDelivery) ...[

                _buildDeliveryOptionTile(

                  option: DeliveryOption.delivery,

                  selected: selected,

                  title: settings.maxDeliveryDistanceKm > 0

                      ? 'cart_delivery_max'.tr(namedArgs: {

                          'km': settings.maxDeliveryDistanceKm

                              .toStringAsFixed(0),

                        })

                      : 'cart_delivery'.tr(),

                  isApproved: deliveryApproved,

                  hint: selected == DeliveryOption.delivery &&

                          !deliveryApproved

                      ? remainingHint

                      : (deliveryApproved

                          ? 'cart_delivery_ready'.tr(namedArgs: {

                              'amount': sellerSubtotal.toStringAsFixed(2),

                              'currency': settings.orderCurrency,

                            })

                          : null),

                  onTap: () =>

                      _onDeliveryChanged(sellerId, DeliveryOption.delivery),

                ),

                if (selected == DeliveryOption.delivery)

                  Align(

                    alignment: Alignment.centerLeft,

                    child: TextButton.icon(

                      onPressed:

                          _isCheckingDelivery ? null : _refreshLocation,

                      icon: const Icon(Icons.my_location, size: 18),

                      label: Text(

                        _buyerPosition == null

                            ? 'cart_check_location'.tr()

                            : 'cart_refresh_location'.tr(),

                      ),

                    ),

                  ),

              ],

              if (!settings.offersPickup && !settings.offersDelivery)

                Text(

                  'cart_no_delivery_options'.tr(),

                  style: TextStyle(color: Colors.orange[800], fontSize: 13),

                ),

            ],

          ),

        );

      }).toList(),

    );

  }



  Widget _buildPremiumOrderHint(PremiumAccess access) {
    final items = ref.watch(cartProvider);
    if (!cartUpcomingRequiresPremium(items)) {
      return const SizedBox.shrink();
    }
    if (access.canReserveUpcomingInCart) {
      return const SizedBox.shrink();
    }

    final productId =
        RevenueCatConfig.recommendedProductIdForRole(access.role);
    final titleKey = RevenueCatConfig.titleKeyForProductId(productId);
    final priceKey = RevenueCatConfig.priceKeyForProductId(productId);
    if (titleKey == null || priceKey == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Text(
        'cart_premium_required'.tr(namedArgs: {
          'plan': titleKey.tr(),
          'price': priceKey.tr(),
        }),
        style: TextStyle(
          color: Colors.amber.shade900,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatCartItemUnitPrice(CartItem item) {
    final unit = ProductUnits.normalize(item.unit);
    return ProductPriceText.format(
      context,
      ref,
      item.price,
      originalCurrency: item.originalCurrency,
      unit: unit,
      unitDescription: item.unitDescription,
    );
  }

  String _formatConvertedAmount(double amount, String originalCurrency) {
    return ProductPriceText.formatAmountOnly(
      context,
      ref,
      amount,
      originalCurrency: originalCurrency,
    );
  }

  String _formatCartTotal(List<CartItem> items) {
    return CurrencyService().formatDual(_cartConvertedTotal(items));
  }

  ConvertedPrice _cartConvertedTotal(List<CartItem> items) {
    final region = ref.read(currencyRegionProvider);
    return CurrencyService().convertCartTotal(
      lines: items
          .map(
            (item) => (
              lineTotal: item.lineTotal,
              originalCurrency: item.originalCurrency,
            ),
          )
          .toList(),
      locale: context.locale,
      currencyRegion: region,
    );
  }

  Widget _buildCartItemCard(CartItem item) {
    final unit = ProductUnits.normalize(item.unit);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🌾 ${item.sellerName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  TranslatedText(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatCartItemUnitPrice(item),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      QuantityStepper(
                        compact: true,
                        quantity: item.quantity,
                        unit: unit,
                        onChanged: (newQty) => ref
                            .read(cartProvider.notifier)
                            .setQuantity(item.id, newQty),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${'cart_line_total'.tr()}: ${_formatConvertedAmount(item.lineTotal, item.originalCurrency)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 22,
                        ),
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .removeFromCart(item.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override

  Widget build(BuildContext context) {

    ref.listen<List<CartItem>>(cartProvider, (_, __) => _validateCart());



    final cartItems = ref.watch(cartProvider);

    final access = ref.watch(premiumAccessProvider);

    final blockingIssues = [

      ..._issues.where((issue) => !_isMinOrderIssue(issue, cartItems)),

      ..._deliveryIssues,

    ];

    final minOrderBlocked = _hasMinOrderBlock(cartItems);

    final canOrder = cartItems.isNotEmpty &&

        blockingIssues.isEmpty &&

        !minOrderBlocked &&

        !_isValidating &&

        !_isCheckingDelivery;



    return Scaffold(

      appBar: AppBar(

        title: Text(localizedMyPrefixedTitle(context, 'cart_title')),

        backgroundColor: Colors.green[700],

        foregroundColor: Colors.white,

        actions: [

          FarmerHelperIconButton(guideSteps: _guideSteps),

          if (cartItems.isNotEmpty)

            IconButton(

              icon: const Icon(Icons.delete_sweep_outlined),

              tooltip: 'cart_clear_tooltip'.tr(),

              onPressed: () {

                showDialog(

                  context: context,

                  builder: (_) => AlertDialog(

                    title: Text('cart_clear_title'.tr()),

                    content: Text('cart_clear_confirm'.tr()),

                    actions: [

                      TextButton(

                        onPressed: () => Navigator.pop(context),

                        child: Text('cart_cancel'.tr()),

                      ),

                      ElevatedButton(

                        onPressed: () {

                          ref.read(cartProvider.notifier).clearCart();

                          Navigator.pop(context);

                        },

                        style: ElevatedButton.styleFrom(

                          backgroundColor: Colors.red,

                        ),

                        child: Text(

                          'cart_clear_btn'.tr(),

                          style: const TextStyle(color: Colors.white),

                        ),

                      ),

                    ],

                  ),

                );

              },

            ),

        ],

      ),

      body: cartItems.isEmpty

          ? Center(

              child: Column(

                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  Icon(

                    Icons.shopping_basket_outlined,

                    size: 80,

                    color: Colors.grey[400],

                  ),

                  const SizedBox(height: 16),

                  Text(

                    'cart_empty'.tr(),

                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),

                  ),

                  const SizedBox(height: 8),

                  Text(

                    'cart_empty_hint'.tr(),

                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),

                  ),

                ],

              ),

            )

          : Column(

              children: [

                Expanded(

                  child: ListView(

                    padding: const EdgeInsets.all(12),

                    children: [

                      _buildPaymentMethodSection(cartItems),

                      const SizedBox(height: 8),

                      ...cartItems.map(
                        (item) => _buildCartItemCard(item),
                      ),

                      _buildDeliverySection(cartItems),

                    ],

                  ),

                ),

                SafeArea(
                  key: _guideCheckoutKey,
                  top: false,
                  child: Container(

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(

                    color: Colors.white,

                    boxShadow: [

                      BoxShadow(

                        color: Colors.black.withValues(alpha: 0.05),

                        blurRadius: 10,

                        offset: const Offset(0, -5),

                      ),

                    ],

                  ),

                  child: Column(

                    children: [

                      if (blockingIssues.isNotEmpty)

                        ...blockingIssues.map(

                          (issue) => Container(

                            width: double.infinity,

                            margin: const EdgeInsets.only(bottom: 8),

                            padding: const EdgeInsets.all(12),

                            decoration: BoxDecoration(

                              color: Colors.red[50],

                              borderRadius: BorderRadius.circular(10),

                              border: Border.all(color: Colors.red[200]!),

                            ),

                            child: Text(

                              issue.message,

                              textAlign: TextAlign.center,

                              style: TextStyle(

                                color: Colors.red[800],

                                fontWeight: FontWeight.w600,

                                fontSize: 13,

                              ),

                            ),

                          ),

                        ),

                      if (_isValidating || _isCheckingDelivery)

                        const Padding(

                          padding: EdgeInsets.only(bottom: 12),

                          child: LinearProgressIndicator(minHeight: 2),

                        ),

                      _buildPremiumOrderHint(access),

                      Row(

                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [

                          Text(

                            'cart_items_count'
                                .tr(namedArgs: {'count': '${cartItems.length}'}),

                            style: TextStyle(color: Colors.grey[600]),

                          ),

                          Text(

                            '${'cart_total'.tr()}: ${_formatCartTotal(cartItems)}',

                            style: TextStyle(

                              fontSize: 18,

                              fontWeight: FontWeight.bold,

                              color: Colors.green[700],

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 12),

                      SizedBox(

                        width: double.infinity,

                        height: 50,

                        child: ElevatedButton(

                          onPressed: canOrder ? _placeOrder : null,

                          style: ElevatedButton.styleFrom(

                            backgroundColor:

                                canOrder ? Colors.green[700] : Colors.grey[400],

                            disabledBackgroundColor: Colors.grey[400],

                            foregroundColor: Colors.white,

                            disabledForegroundColor: Colors.white70,

                            shape: RoundedRectangleBorder(

                              borderRadius: BorderRadius.circular(15),

                            ),

                          ),

                          child: Text(

                            'cart_order_all'.tr(),

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                        ),

                      ),

                    ],

                  ),

                ),
                ),

              ],

            ),

    );

  }

}

