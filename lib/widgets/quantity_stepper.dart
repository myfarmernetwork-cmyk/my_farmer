import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_units.dart';
import '../theme/agro_accent_colors.dart';
import '../utils/quantity_helper.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.unit,
    required this.onChanged,
    this.compact = false,
    this.maxQuantity,
    this.marketplaceStyle = false,
  });

  final double quantity;
  final String unit;
  final ValueChanged<double> onChanged;
  final bool compact;
  final double? maxQuantity;
  final bool marketplaceStyle;

  double _clampQuantity(double value) {
    final min = QuantityHelper.minimum(unit);
    var normalized = QuantityHelper.normalize(value, unit);
    if (normalized < min) normalized = min;
    final max = maxQuantity;
    if (max != null && normalized > max) {
      normalized = QuantityHelper.normalize(max, unit);
    }
    return normalized;
  }

  Future<void> _showQuantityDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: QuantityHelper.formatValue(quantity, unit),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final parsed = _parseInput(controller.text);
              if (parsed == null) {
                setDialogState(
                  () => errorText = 'quantity_enter_invalid'.tr(),
                );
                return;
              }

              final max = maxQuantity;
              if (max != null && parsed > max + 0.0001) {
                setDialogState(
                  () => errorText = 'quantity_enter_max'.tr(
                    namedArgs: {
                      'max': QuantityHelper.formatWithUnit(max, unit),
                    },
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext, _clampQuantity(parsed));
            }

            return AlertDialog(
              title: Text('quantity_enter_title'.tr()),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: QuantityHelper.usesDecimalSteps(unit),
                  signed: false,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    QuantityHelper.usesDecimalSteps(unit)
                        ? RegExp(r'[\d,.]')
                        : RegExp(r'\d'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: ProductUnits.shortLabel(unit),
                  errorText: errorText,
                ),
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('cart_cancel'.tr()),
                ),
                TextButton(
                  onPressed: submit,
                  child: Text('ok'.tr()),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result > 0) {
      onChanged(result);
    }
  }

  double? _parseInput(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final label = QuantityHelper.formatWithUnit(quantity, unit);
    final radius = compact ? 10.0 : 12.0;

    final decoration = marketplaceStyle
        ? BoxDecoration(
            color: AgroAccentColors.marketplaceChipGreen,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
            ),
          )
        : BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.grey.shade300),
          );

    final minusColor = marketplaceStyle
        ? Colors.white.withValues(alpha: 0.96)
        : Colors.grey.shade700;
    final plusColor = marketplaceStyle
        ? Colors.white.withValues(alpha: 0.96)
        : Colors.green.shade700;
    final labelColor = marketplaceStyle
        ? const Color(0xFFFFEB3B)
        : Colors.green.shade800;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.remove_circle_outline,
              color: minusColor,
              size: compact ? 22 : 24,
            ),
            onPressed: () {
              final next = QuantityHelper.decrease(quantity, unit);
              onChanged(next);
            },
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showQuantityDialog(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 14 : 15,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                  decorationColor: marketplaceStyle
                      ? labelColor.withValues(alpha: 0.7)
                      : null,
                  color: labelColor,
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.add_circle_outline,
              color: plusColor,
              size: compact ? 22 : 24,
            ),
            onPressed: () {
              onChanged(_clampQuantity(QuantityHelper.increase(quantity, unit)));
            },
          ),
        ],
      ),
    );
  }
}
