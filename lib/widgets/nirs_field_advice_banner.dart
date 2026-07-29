import 'package:flutter/material.dart';

import '../models/nirs_scan_result.dart';
import '../utils/nirs_labels.dart';

class NirsFieldAdviceBanner extends StatelessWidget {
  const NirsFieldAdviceBanner({super.key, required this.scan});

  final NirsScanResult scan;

  @override
  Widget build(BuildContext context) {
    final isCritical = scan.ndviMean < 0.45 || scan.moistureIndex < 40;
    final bg = isCritical ? Colors.orange.shade50 : Colors.teal.shade50;
    final border = isCritical ? Colors.orange.shade200 : Colors.teal.shade200;
    final iconColor = isCritical ? Colors.orange.shade800 : Colors.teal.shade800;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nirsLabel(context, 'land_nirs_advice_title'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nirsLabel(context, scan.adviceKey),
                  style: TextStyle(
                    height: 1.4,
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
