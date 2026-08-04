import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// B2B analitika tržišta — dostupna tvrtkama uz poslovnu pretplatu (19,99 €/mj).
class CompanyMarketAnalyticsScreen extends StatelessWidget {
  const CompanyMarketAnalyticsScreen({super.key});

  static const _demandStats = [
    _B2BStatChip(labelKey: 'company_b2b_stat_fertilizers', value: '42%'),
    _B2BStatChip(labelKey: 'company_b2b_stat_plant_protection', value: '35%'),
  ];

  static const _aiStats = [
    _B2BStatChip(labelKey: 'company_b2b_stat_ai_impressions', value: '124'),
    _B2BStatChip(labelKey: 'company_b2b_stat_ai_clicks', value: '38'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('company_b2b_analytics_title'.tr()),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 72,
            color: Colors.deepPurple.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'company_b2b_analytics_title'.tr(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'company_b2b_analytics_subtitle'.tr(),
            style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          _metricCard(
            context,
            icon: Icons.trending_up,
            titleKey: 'company_b2b_metric_demand',
            bodyKey: 'company_b2b_detail_demand_body',
            stats: _demandStats,
          ),
          _metricCard(
            context,
            icon: Icons.storefront,
            titleKey: 'company_b2b_metric_regions',
            bodyKey: 'company_b2b_detail_regions_body',
          ),
          _metricCard(
            context,
            icon: Icons.auto_awesome,
            titleKey: 'company_b2b_metric_ai',
            bodyKey: 'company_b2b_detail_ai_body',
            stats: _aiStats,
          ),
        ],
        ),
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required IconData icon,
    required String titleKey,
    required String bodyKey,
    List<_B2BStatChip> stats = const [],
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showMetricDetail(
          context,
          icon: icon,
          titleKey: titleKey,
          bodyKey: bodyKey,
          stats: stats,
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.deepPurple.shade50,
            child: Icon(icon, color: Colors.deepPurple.shade700),
          ),
          title: Text(
            titleKey.tr(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: Icon(Icons.chevron_right, color: Colors.deepPurple.shade400),
        ),
      ),
    );
  }

  void _showMetricDetail(
    BuildContext context, {
    required IconData icon,
    required String titleKey,
    required String bodyKey,
    List<_B2BStatChip> stats = const [],
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: stats.isEmpty ? 0.42 : 0.52,
          minChildSize: 0.32,
          maxChildSize: 0.78,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.deepPurple.shade50,
                        child: Icon(icon, color: Colors.deepPurple.shade700),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          titleKey.tr(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.deepPurple.shade100),
                    ),
                    child: Text(
                      bodyKey.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'company_b2b_detail_highlights'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: stats
                          .map((stat) => _statChip(sheetContext, stat))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text('farmer_helper_close'.tr()),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statChip(BuildContext context, _B2BStatChip stat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.labelKey.tr(),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _B2BStatChip {
  const _B2BStatChip({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}
