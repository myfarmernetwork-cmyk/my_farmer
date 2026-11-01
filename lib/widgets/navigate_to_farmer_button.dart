import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/buyer/storefront_seller_data.dart';
import '../models/farmer_shop_settings.dart';
import '../models/order.dart' as app_order;
import '../repositories/product_repository.dart';
import '../services/farmer_navigation_service.dart';
import '../theme/agro_accent_colors.dart';
import '../utils/order_status.dart';

class NavigateToFarmerButton extends StatelessWidget {
  const NavigateToFarmerButton({
    super.key,
    required this.name,
    this.address = '',
    this.lat,
    this.lng,
    this.marketplaceStyle = false,
  });

  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final bool marketplaceStyle;

  static const _priceYellow = Color(0xFFFFEB3B);
  static const _buttonHeight = 48.0;

  static bool canNavigate({
    required String address,
    double? lat,
    double? lng,
  }) {
    return (lat != null && lng != null) || address.trim().isNotEmpty;
  }

  static bool canNavigateSeller({
    required StorefrontSellerData seller,
    required FarmerShopSettings settings,
  }) {
    return canNavigate(
      address: seller.address,
      lat: settings.farmLat,
      lng: settings.farmLng,
    );
  }

  Future<void> _open(BuildContext context) async {
    final ok = await openFarmerDirections(
      name: name,
      address: address,
      lat: lat,
      lng: lng,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('farmer_navigate_failed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chipGreen = AgroAccentColors.marketplaceChipGreen;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.directions),
        label: Text('farmer_navigate'.tr()),
        style: marketplaceStyle
            ? FilledButton.styleFrom(
                backgroundColor: _priceYellow,
                foregroundColor: chipGreen,
                minimumSize: const Size(double.infinity, _buttonHeight),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                shape: const StadiumBorder(),
              )
            : FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
      ),
    );
  }
}

class OrderNavigateToFarmerButton extends ConsumerStatefulWidget {
  const OrderNavigateToFarmerButton({
    super.key,
    required this.order,
  });

  final app_order.Order order;

  static bool shouldShow(app_order.Order order, {required bool isBuyerView}) {
    if (!isBuyerView) return false;
    if (order.deliveryType == 'delivery') return false;
    final code = order.statusCode;
    return code == OrderStatus.preparing || code == OrderStatus.completed;
  }

  @override
  ConsumerState<OrderNavigateToFarmerButton> createState() =>
      _OrderNavigateToFarmerButtonState();
}

class _OrderNavigateToFarmerButtonState
    extends ConsumerState<OrderNavigateToFarmerButton> {
  FarmerShopSettings? _settings;
  String _address = '';
  bool _loading = true;
  bool _canNavigate = false;

  @override
  void initState() {
    super.initState();
    _loadSellerLocation();
  }

  Future<void> _loadSellerLocation() async {
    final sellerId = widget.order.sellerId.trim();
    if (sellerId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final data =
          await ref.read(productRepositoryProvider).getSellerData(sellerId);
      if (!mounted) return;
      if (data == null) {
        setState(() => _loading = false);
        return;
      }

      final seller = StorefrontSellerData.fromMap(data);
      final settings = FarmerShopSettings.fromMap(seller.raw);
      setState(() {
        _settings = settings;
        _address = seller.address;
        _canNavigate = NavigateToFarmerButton.canNavigate(
          address: seller.address,
          lat: settings.farmLat,
          lng: settings.farmLng,
        );
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!_canNavigate || _settings == null) {
      return const SizedBox.shrink();
    }

    return NavigateToFarmerButton(
      name: widget.order.sellerName,
      address: _address,
      lat: _settings!.farmLat,
      lng: _settings!.farmLng,
      marketplaceStyle: true,
    );
  }
}
