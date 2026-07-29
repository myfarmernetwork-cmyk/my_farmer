import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/nirs_scan_result.dart';
import '../utils/nirs_labels.dart';

class NirsScanComparisonCard extends StatelessWidget {
  const NirsScanComparisonCard({
    super.key,
    required this.latest,
    required this.previous,
  });

  final NirsScanResult latest;
  final NirsScanResult previous;

  @override
  Widget build(BuildContext context) {
    final delta = latest.ndviDeltaFrom(previous) ?? 0;
    final deltaLabel = delta > 0.005
        ? nirsLabelArgs(
            context,
            'land_nirs_compare_up',
            {'delta': delta.toStringAsFixed(3)},
          )
        : delta < -0.005
            ? nirsLabelArgs(
                context,
                'land_nirs_compare_down',
                {'delta': delta.abs().toStringAsFixed(3)},
              )
            : nirsLabel(context, 'land_nirs_compare_stable');

    final deltaColor = delta > 0.005
        ? Colors.green.shade700
        : delta < -0.005
            ? Colors.red.shade700
            : Colors.grey.shade700;

    final deltaIcon = delta > 0.005
        ? Icons.trending_up
        : delta < -0.005
            ? Icons.trending_down
            : Icons.trending_flat;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nirsLabel(context, 'land_nirs_compare_title'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CompareTile(
                  label: nirsLabel(context, 'land_nirs_compare_previous'),
                  ndvi: previous.ndviMean.toStringAsFixed(3),
                ),
              ),
              Icon(deltaIcon, color: deltaColor),
              Expanded(
                child: _CompareTile(
                  label: nirsLabel(context, 'land_nirs_compare_current'),
                  ndvi: latest.ndviMean.toStringAsFixed(3),
                  highlight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            deltaLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: deltaColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareTile extends StatelessWidget {
  const _CompareTile({
    required this.label,
    required this.ndvi,
    this.highlight = false,
  });

  final String label;
  final String ndvi;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          ndvi,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.green.shade900 : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

class NirsScanHistoryList extends StatelessWidget {
  const NirsScanHistoryList({super.key, required this.scans});

  final List<NirsScanResult> scans;

  @override
  Widget build(BuildContext context) {
    if (scans.length <= 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nirsLabel(context, 'land_nirs_history_title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...scans.take(5).map((scan) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scan.ndviColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat.yMMMd(context.locale.toString())
                        .add_Hm()
                        .format(scan.displayImageryDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                Text(
                  'NDVI ${scan.ndviMean.toStringAsFixed(3)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scan.ndviColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
