import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cart_item.dart';
import '../../config/marketplace_payment_config.dart';
import '../../config/payment_config.dart';
import '../../models/payment_method.dart';
import '../../models/premium_access.dart';
import '../../models/product.dart';
import '../../models/product_units.dart';
import '../../repositories/product_repository.dart';
import '../../services/currency_service.dart';
import '../../utils/quantity_helper.dart';

class CartStockValidationResult {
  const CartStockValidationResult({
    required this.canProceed,
    required this.wasAdjusted,
  });

  final bool canProceed;
  final bool wasAdjusted;
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  static const Duration cartExpiryDuration = Duration(minutes: 15);

  Timer? _expiryTimer;

  void _touchExpiryTimer() {
    _expiryTimer?.cancel();
    if (state.isEmpty) {
      _expiryTimer = null;
      return;
    }
    _expiryTimer = Timer(cartExpiryDuration, () {
      state = [];
      _expiryTimer = null;
    });
  }

  void addToCart(CartItem item) {
    final normalizedUnit = ProductUnits.normalize(item.unit);
    final quantity = item.quantity > 0
        ? QuantityHelper.normalize(item.quantity, normalizedUnit)
        : QuantityHelper.minimum(normalizedUnit);

    final index = state.indexWhere((element) => element.id == item.id);
    if (index >= 0) {
      final updated = [...state];
      updated[index] = updated[index].copyWith(
        unit: normalizedUnit,
        unitDescription: item.unitDescription.trim(),
        originalCurrency:
            CurrencyService.normalizeCode(item.originalCurrency),
        isUpcoming: item.isUpcoming || updated[index].isUpcoming,
        quantity: QuantityHelper.normalize(
          updated[index].quantity + quantity,
          normalizedUnit,
        ),
      );
      state = updated;
    } else {
      state = [
        ...state,
        item.copyWith(
          quantity: quantity,
          unit: normalizedUnit,
          unitDescription: item.unitDescription.trim(),
          originalCurrency: CurrencyService.normalizeCode(item.originalCurrency),
        ),
      ];
    }
    _touchExpiryTimer();
  }

  void setQuantity(String productId, double quantity) {
    final index = state.indexWhere((item) => item.id == productId);
    if (index < 0) return;

    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final item = state[index];
    final normalizedUnit = ProductUnits.normalize(item.unit);
    final updated = [...state];
    updated[index] = updated[index].copyWith(
      quantity: QuantityHelper.normalize(quantity, normalizedUnit),
    );
    state = updated;
    _touchExpiryTimer();
  }

  void adjustQuantity(String productId, {required bool increase}) {
    final index = state.indexWhere((item) => item.id == productId);
    if (index < 0) return;

    final item = state[index];
    final newQty = increase
        ? QuantityHelper.increase(item.quantity, item.unit)
        : QuantityHelper.decrease(item.quantity, item.unit);

    if (newQty <= 0) {
      removeFromCart(productId);
      return;
    }

    final updated = [...state];
    updated[index] = updated[index].copyWith(quantity: newQty);
    state = updated;
    _touchExpiryTimer();
  }

  void removeFromCart(String productId) {
    state = state.where((item) => item.id != productId).toList();
    _touchExpiryTimer();
  }

  void clearCart() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    state = [];
  }

  /// Reads live Firestore stock before checkout. Does not reserve or mutate stock.
  Future<CartStockValidationResult> validateStockAgainstServer(
    ProductRepository productRepository,
  ) async {
    if (state.isEmpty) {
      return const CartStockValidationResult(
        canProceed: false,
        wasAdjusted: false,
      );
    }

    final productIds = state.map((item) => item.id).toSet();
    final products = await productRepository.fetchProductsByIds(productIds);

    var wasAdjusted = false;
    final updatedItems = <CartItem>[];

    for (final item in state) {
      final product = products[item.id];
      final adjustedItem = _clampItemToAvailableStock(item, product);

      if (adjustedItem == null) {
        wasAdjusted = true;
        continue;
      }

      if (adjustedItem.quantity != item.quantity) {
        wasAdjusted = true;
      }

      updatedItems.add(adjustedItem);
    }

    if (wasAdjusted) {
      state = updatedItems;
      _touchExpiryTimer();
      return const CartStockValidationResult(
        canProceed: false,
        wasAdjusted: true,
      );
    }

    return const CartStockValidationResult(
      canProceed: true,
      wasAdjusted: false,
    );
  }

  CartItem? _clampItemToAvailableStock(CartItem item, Product? product) {
    if (product == null || product.isUnavailable) {
      return null;
    }

    final minQty = QuantityHelper.minimum(item.unit);
    final available = product.stock;

    if (available < minQty) {
      return null;
    }

    if (item.quantity <= available) {
      return item;
    }

    final clamped = QuantityHelper.normalize(available, item.unit);
    if (clamped < minQty) {
      return null;
    }

    return item.copyWith(quantity: clamped);
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}

bool cartRequiresDirectSellerPayment(List<CartItem> items) {
  return items.any((item) => item.isUpcoming);
}

bool cartRequiresDigitalPayment(List<CartItem> items) {
  return cartRequiresDirectSellerPayment(items);
}

/// Rezervacija robe u dolasku zahtijeva Premium (Kupac 1,99 € / Hobi 3,99 €).
/// Standardna kupovina dostupnih artikala (keš/kartica) ostaje besplatna za sve kupce.
bool cartUpcomingRequiresPremium(List<CartItem> items) =>
    cartRequiresDigitalPayment(items);

bool canCheckoutCart({
  required PremiumAccess access,
  required List<CartItem> items,
}) {
  if (!cartUpcomingRequiresPremium(items)) return true;
  return access.canReserveUpcomingInCart;
}

CartPaymentMethod defaultPaymentMethodForCart(List<CartItem> items) {
  if (cartRequiresDirectSellerPayment(items)) {
    return CartPaymentMethod.directPaypal;
  }
  return CartPaymentMethod.cash;
}

bool isPlatformCardPaymentAvailable() => PaymentConfig.isStripeConfigured;

bool isAllowedPaymentMethod({
  required List<CartItem> items,
  required String paymentMethod,
}) {
  final method = CartPaymentMethod.fromValue(paymentMethod);
  final platformCard = isPlatformCardPaymentAvailable() &&
      (method == CartPaymentMethod.stripe ||
          method == CartPaymentMethod.googlePay);

  if (MarketplacePaymentConfig.peerToPeerOnly) {
    if (cartRequiresDirectSellerPayment(items)) {
      return method == CartPaymentMethod.directPaypal ||
          method == CartPaymentMethod.bankTransfer ||
          platformCard;
    }
    return method.isPeerToPeer || platformCard;
  }
  if (cartRequiresDigitalPayment(items)) {
    return method.isDigital;
  }
  return true;
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final notifier = CartNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});
