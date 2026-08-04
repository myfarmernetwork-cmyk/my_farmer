import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/premium_access.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/product_price_text.dart';
import '../../widgets/quantity_stepper.dart';
import '../../widgets/translated_text.dart';
import '../../models/product.dart';
import '../../models/cart_item.dart';
import '../../models/payment_method.dart';
import '../../models/payment_result.dart';
import '../../providers/locale_settings_provider.dart';
import '../../services/currency_service.dart';
import '../../services/payment_service.dart';
import '../../config/payment_config.dart';
import '../../config/marketplace_payment_config.dart';
import '../../services/peer_marketplace_payment_service.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/review_repository.dart';
import '../../utils/quantity_helper.dart';
import '../../widgets/harvest_countdown_overlay.dart';
import '../../widgets/product_sold_out_overlay.dart';
import '../chat/chat_screen.dart';
import 'cart_provider.dart';
import 'farmer_storefront_screen.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  late double _quantity;

  Product get product => widget.product;

  @override
  void initState() {
    super.initState();
    _quantity = _initialQuantity();
  }

  double _initialQuantity() {
    final min = QuantityHelper.minimum(product.displayUnit);
    if (product.isUnavailable) return min;
    if (product.stock < min) return min;
    return min;
  }

  double get _maxSelectableQuantity {
    if (product.isUnavailable) {
      return QuantityHelper.minimum(product.displayUnit);
    }
    return product.stock;
  }

  void _updateQuantity(double qty) {
    if (product.isUnavailable) return;
    final min = QuantityHelper.minimum(product.displayUnit);
    final max = _maxSelectableQuantity;
    final clamped = qty.clamp(min, max);
    setState(() {
      _quantity = QuantityHelper.normalize(clamped, product.displayUnit);
    });
  }

  bool get _isUnavailable => product.isUnavailable;

  bool get _isUpcomingActive => product.isHarvestCountdownActive;

  double get _lineTotal => product.price * _quantity;

  bool get _requiresDigitalPayment => product.isUpcoming;

  ConvertedPrice get _convertedLineTotal {
    return CurrencyService().convertCartTotal(
      lines: [
        (
          lineTotal: _lineTotal,
          originalCurrency: product.originalCurrency,
        ),
      ],
      locale: context.locale,
      currencyRegion: ref.read(currencyRegionProvider),
    );
  }

  Future<void> _checkoutWithMethod(
    BuildContext context,
    CartPaymentMethod method,
  ) async {
    try {
      final converted = _convertedLineTotal;
      final amountLabel =
          '${converted.displayAmount.toStringAsFixed(2)} ${converted.displayCurrency}';

      if (MarketplacePaymentConfig.peerToPeerOnly &&
          !method.requiresDigitalProcessing) {
        final peerService = PeerMarketplacePaymentService();
        final seller = await peerService.loadSellerDetails(product.sellerId);

        if (!context.mounted) return;

        final paymentResult = await peerService.confirmPeerPayment(
          context: context,
          method: method,
          seller: seller,
          amountLabel: amountLabel,
        );

        if (!context.mounted || paymentResult == null) return;

        await _placeOrder(
          context,
          paymentMethod: paymentResult.paymentMethod,
          paymentStatus: paymentResult.paymentStatus,
        );
        return;
      }

      if (method == CartPaymentMethod.cash) {
        await _placeOrder(
          context,
          paymentMethod: 'cash',
        );
        return;
      }

      final paymentResult = await ref.read(paymentServiceProvider).processPayment(
            context: context,
            method: method,
            amount: converted.displayAmount,
            currency: converted.displayCurrency,
            sellerId: product.sellerId,
          );

      if (!context.mounted || paymentResult == null) return;

      await _placeOrder(
        context,
        paymentMethod: paymentResult.paymentMethod,
        paymentStatus: paymentResult.paymentStatus,
        transactionId: paymentResult.transactionId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common_error'.tr(namedArgs: {'error': '$e'}))),
        );
      }
    }
  }

  String _orderSuccessMessage({
    required String paymentMethod,
    required String paymentStatus,
  }) {
    if (paymentMethod == 'direct_paypal') {
      return 'peer_payment_order_success_paypal'.tr();
    }
    if (paymentMethod == 'bank_transfer') {
      return 'peer_payment_order_success_bank'.tr();
    }
    if (paymentMethod == 'paypal') {
      return paymentStatus == PaymentStatus.paid
          ? 'product_order_paypal_paid_success'.tr()
          : 'product_order_paypal_success'.tr();
    }
    if (paymentMethod == 'stripe' || paymentMethod == 'google_pay') {
      return 'product_order_digital_paid_success'.tr();
    }
    return 'product_order_cash_success'.tr();
  }

  Future<void> _placeOrder(
    BuildContext context, {
    required String paymentMethod,
    String paymentStatus = PaymentStatus.pending,
    String? transactionId,
  }) async {
    try {
      await ref.read(orderRepositoryProvider).createSingleProductOrder(
            product: product,
            paymentMethod: paymentMethod,
            paymentStatus: paymentStatus,
            transactionId: transactionId,
            quantity: _quantity,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_orderSuccessMessage(
              paymentMethod: paymentMethod,
              paymentStatus: paymentStatus,
            )),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common_error'.tr(namedArgs: {'error': '$e'}))),
        );
      }
    }
  }

  void _showPaymentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'product_select_payment'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${product.name} — ${QuantityHelper.formatWithUnit(_quantity, product.displayUnit)} × ${ProductPriceText.format(context, ref, product.price, originalCurrency: product.originalCurrency, unit: product.displayUnit, unitDescription: product.unitDescription)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  '${'cart_line_total'.tr()}: ${ProductPriceText.formatAmountOnly(context, ref, _lineTotal, originalCurrency: product.originalCurrency)}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'peer_payment_disclaimer_short'.tr(),
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_requiresDigitalPayment) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
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
                ],
                const SizedBox(height: 16),
                if (!_requiresDigitalPayment) ...[
                  _buildPaymentOption(
                    label: 'product_cash_on_pickup'.tr(),
                    subtitle: 'product_pay_on_delivery'.tr(),
                    icon: Icons.money,
                    color: Colors.green.shade700,
                    onTap: () {
                      Navigator.pop(ctx);
                      _checkoutWithMethod(context, CartPaymentMethod.cash);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (PaymentConfig.isStripeConfigured) ...[
                  _buildPaymentOption(
                    label: 'cart_payment_stripe'.tr(),
                    subtitle: 'payment_option_stripe_live_hint'.tr(),
                    icon: Icons.credit_card,
                    color: Colors.indigo.shade700,
                    onTap: () {
                      Navigator.pop(ctx);
                      _checkoutWithMethod(context, CartPaymentMethod.stripe);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                _buildPaymentOption(
                  label: 'peer_payment_option_paypal'.tr(),
                  subtitle: 'peer_payment_option_paypal_hint'.tr(),
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFF003087),
                  onTap: () {
                    Navigator.pop(ctx);
                    _checkoutWithMethod(context, CartPaymentMethod.directPaypal);
                  },
                ),
                const SizedBox(height: 8),
                _buildPaymentOption(
                  label: 'peer_payment_option_bank'.tr(),
                  subtitle: 'peer_payment_option_bank_hint'.tr(),
                  icon: Icons.account_balance,
                  color: Colors.teal.shade700,
                  onTap: () {
                    Navigator.pop(ctx);
                    _checkoutWithMethod(context, CartPaymentMethod.bankTransfer);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      tileColor: color.withValues(alpha: 0.06),
      leading: Icon(icon, color: color, size: 32),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color),
      onTap: onTap,
    );
  }

  void _showReviewModal(BuildContext context) async {
    final reviewRepo = ref.read(reviewRepositoryProvider);
    final orderRepo = ref.read(orderRepositoryProvider);
    final alreadyReviewed = await reviewRepo.hasReviewed(product.sellerId);

    if (!context.mounted) return;

    if (alreadyReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('product_already_reviewed'.tr())),
      );
      return;
    }

    final hasPurchased =
        await orderRepo.hasCompletedOrderFromSeller(product.sellerId);
    if (!context.mounted) return;

    if (!hasPurchased) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('product_review_purchase_required'.tr())),
      );
      return;
    }

    double selectedRating = 5;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: StatefulBuilder(
                builder: (context, setModalState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'product_rate_farmer'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setModalState(
                            () => selectedRating = index + 1.0,
                          ),
                          child: Icon(
                            index < selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 40,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'product_review_comment'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          await reviewRepo.addReview(
                            sellerId: product.sellerId,
                            rating: selectedRating,
                            comment: commentController.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('product_review_thanks'.tr()),
                              ),
                            );
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          final message = e.toString().contains(
                                'product_review_purchase_required',
                              )
                              ? 'product_review_purchase_required'.tr()
                              : 'common_error'.tr(
                                  namedArgs: {'error': '$e'},
                                );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Text('product_send_review'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _addToCart(BuildContext context) {
    final itemToAdd = CartItem(
      id: product.id,
      name: product.name,
      price: product.price,
      originalCurrency: product.originalCurrency,
      unit: product.displayUnit,
      quantity: _quantity,
      unitDescription: product.unitDescription,
      imageUrl: product.imageUrl,
      sellerId: product.sellerId,
      sellerName: product.sellerName,
      isUpcoming: product.isUpcoming,
    );
    ref.read(cartProvider.notifier).addToCart(itemToAdd);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'product_added_to_cart'.tr(
            namedArgs: {'name': product.name},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          product.name,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline),
            tooltip: 'product_rate_farmer'.tr(),
            onPressed: () => _showReviewModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'product_chat_farmer'.tr(),
            onPressed: () => PremiumGate.run(
              context,
              ref,
              feature: PremiumFeature.chat,
              onUnlocked: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    receiverId: product.sellerId,
                    receiverName: product.sellerName,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductSoldOutOverlay(
                show: _isUnavailable,
                child: _isUpcomingActive && product.harvestDateTime != null
                    ? HarvestCountdownOverlay(
                        harvestDateTime: product.harvestDateTime!,
                        isDelivery: product.isDeliveryUpcoming,
                        upcomingMode: product.upcomingMode,
                        child: Image.network(
                          product.imageUrl,
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 250,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, size: 100),
                          ),
                        ),
                      )
                    : Image.network(
                        product.imageUrl,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 250,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, size: 100),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProductPriceText(
                      price: product.price,
                      originalCurrency: product.originalCurrency,
                      unit: product.displayUnit,
                      unitDescription: product.unitDescription,
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'product_available_stock'.tr(
                        namedArgs: {
                          'quantity': QuantityHelper.formatWithUnit(
                            product.stock,
                            product.displayUnit,
                          ),
                        },
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_isUnavailable) ...[
                      const SizedBox(height: 8),
                      Text(
                        'product_sold_out_message'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_isUpcomingActive) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          product.isDeliveryUpcoming
                              ? 'product_upcoming_delivery_reserve_hint'.tr()
                              : 'product_upcoming_reserve_hint'.tr(),
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'product_upcoming_card_payment_hint'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: product.sellerId.trim().isEmpty
                            ? null
                            : () => openSellerProfile(
                                  context,
                                  product.sellerId,
                                ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.green[100],
                              child: const Icon(Icons.person, color: Colors.green),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'product_seller_label'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    product.sellerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.green[700],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'product_description'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    product.description.isEmpty
                        ? Text('product_no_description'.tr())
                        : TranslatedText(product.description),
                    const SizedBox(height: 24),
                    AbsorbPointer(
                      absorbing: _isUnavailable,
                      child: Opacity(
                        opacity: _isUnavailable ? 0.45 : 1,
                        child: Center(
                          child: QuantityStepper(
                            quantity: _quantity,
                            unit: product.displayUnit,
                            onChanged: (qty) {
                              if (qty <= 0) {
                                _updateQuantity(
                                  QuantityHelper.minimum(product.displayUnit),
                                );
                              } else {
                                _updateQuantity(qty);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${'cart_line_total'.tr()}: ${ProductPriceText.formatAmountOnly(context, ref, _lineTotal, originalCurrency: product.originalCurrency)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isUnavailable
                                ? null
                                : () => PremiumGate.run(
                                      context,
                                      ref,
                                      feature: PremiumFeature.orders,
                                      onUnlocked: () => _addToCart(context),
                                    ),
                            child: Text('product_add_to_cart'.tr()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[800],
                              disabledBackgroundColor: Colors.grey,
                            ),
                            onPressed: _isUnavailable
                                ? null
                                : () => PremiumGate.run(
                                      context,
                                      ref,
                                      feature: PremiumFeature.orders,
                                      onUnlocked: () =>
                                          _showPaymentModal(context),
                                    ),
                            child: Text(
                              _isUpcomingActive
                                  ? 'product_reserve_ahead'.tr()
                                  : 'product_buy_now'.tr(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
