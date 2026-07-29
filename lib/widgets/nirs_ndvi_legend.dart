import 'package:flutter/material.dart';

import '../models/nirs_ndvi_level.dart';
import '../utils/nirs_labels.dart';

class NirsNdviLegend extends StatelessWidget {
  const NirsNdviLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            nirsLabel(context, 'land_nirs_legend_title'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.green.shade900,
            ),
          ),
          const SizedBox(height: 8),
          _LegendRow(
            color: Colors.green.shade700,
            label: nirsLabel(context, 'land_nirs_legend_good'),
            range: '≥ ${NirsNdviLevel.goodMin.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 4),
          _LegendRow(
            color: Colors.orange.shade700,
            label: nirsLabel(context, 'land_nirs_legend_moderate'),
            range:
                '${NirsNdviLevel.moderateMin.toStringAsFixed(2)} – ${NirsNdviLevel.goodMin.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 4),
          _LegendRow(
            color: Colors.red.shade700,
            label: nirsLabel(context, 'land_nirs_legend_low'),
            range: '< ${NirsNdviLevel.moderateMin.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.range,
  });

  final Color color;
  final String label;
  final String range;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          range,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
