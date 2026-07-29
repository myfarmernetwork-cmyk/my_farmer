import 'package:flutter/material.dart';

import '../utils/quantity_helper.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.unit,
    required this.onChanged,
    this.compact = false,
  });

  final double quantity;
  final String unit;
  final ValueChanged<double> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = QuantityHelper.formatWithUnit(quantity, unit);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.remove_circle_outline,
              color: Colors.grey.shade700,
              size: compact ? 22 : 24,
            ),
            onPressed: () {
              final next = QuantityHelper.decrease(quantity, unit);
              onChanged(next);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: compact ? 14 : 15,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.add_circle_outline,
              color: Colors.green.shade700,
              size: compact ? 22 : 24,
            ),
            onPressed: () {
              onChanged(QuantityHelper.increase(quantity, unit));
            },
          ),
        ],
      ),
    );
  }
}
