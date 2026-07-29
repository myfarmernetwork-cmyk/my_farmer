import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/farmer_shop_settings.dart';
import '../utils/farmer_shop_localization.dart';

class FarmerShopInfoCard extends StatelessWidget {
  final FarmerShopSettings settings;
  final bool compact;

  const FarmerShopInfoCard({
    super.key,
    required this.settings,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: Colors.green[200]!),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront, color: Colors.green[800], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  compact ? 'shop_farmer_info'.tr() : 'profile_shop_section'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                    fontSize: compact ? 14 : 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.circle,
            'shop_status'.tr(),
            FarmerShopLocalization.availability(settings.isAvailable),
            valueColor: settings.isAvailable ? Colors.green[700] : Colors.red,
            leadingColor: settings.isAvailable ? Colors.green : Colors.red,
          ),
          if (settings.offersPickup) ...[
            const SizedBox(height: 8),
            _infoRow(
              Icons.store_mall_directory_outlined,
              'cart_pickup'.tr(),
              FarmerShopLocalization.pickupDays(settings),
            ),
          ],
          if (settings.offersDelivery) ...[
            const SizedBox(height: 8),
            _infoRow(
              Icons.local_shipping_outlined,
              'cart_delivery'.tr(),
              FarmerShopLocalization.deliveryDays(settings),
            ),
            const SizedBox(height: 8),
            _infoRow(
              Icons.map_outlined,
              'profile_delivery_zones'.tr(),
              FarmerShopLocalization.deliveryZones(settings),
            ),
          ],
          if (settings.workingDays.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(
              Icons.calendar_today_outlined,
              'profile_working_days'.tr(),
              FarmerShopLocalization.workingDays(settings),
            ),
          ],
          if (settings.workingHours.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(
              Icons.access_time,
              'profile_working_hours'.tr(),
              settings.workingHours,
            ),
          ],
          const SizedBox(height: 8),
          _infoRow(
            Icons.delivery_dining_outlined,
            'shop_options'.tr(),
            FarmerShopLocalization.deliveryOptions(settings),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    Color? leadingColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: leadingColor ?? Colors.green[700]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
