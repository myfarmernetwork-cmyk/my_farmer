import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Uvjeti korištenja tržnice — My Farmer nije platni posrednik.
class MarketplaceTermsScreen extends StatelessWidget {
  const MarketplaceTermsScreen({super.key});

  static const _sections = [
    _TermsSection('legal_terms_role_title', 'legal_terms_role_body'),
    _TermsSection('legal_terms_payments_title', 'legal_terms_payments_body'),
    _TermsSection('legal_terms_seller_title', 'legal_terms_seller_body'),
    _TermsSection('legal_terms_buyer_title', 'legal_terms_buyer_body'),
    _TermsSection('legal_terms_premium_title', 'legal_terms_premium_body'),
    _TermsSection('legal_terms_disputes_title', 'legal_terms_disputes_body'),
    _TermsSection('legal_terms_acceptance_title', 'legal_terms_acceptance_body'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('legal_marketplace_terms_title'.tr()),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel_outlined, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'legal_marketplace_terms_subtitle'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'peer_payment_disclaimer_short'.tr(),
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final section in _sections) ...[
            Text(
              section.titleKey.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              section.bodyKey.tr(),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'legal_terms_footer'.tr(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _TermsSection {
  const _TermsSection(this.titleKey, this.bodyKey);

  final String titleKey;
  final String bodyKey;
}

/// Poveznica na uvjete u profilu.
class ProfileLegalTermsTile extends StatelessWidget {
  const ProfileLegalTermsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade100,
          child: Icon(Icons.description_outlined, color: Colors.grey.shade800),
        ),
        title: Text(
          'legal_terms_profile_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('legal_terms_profile_subtitle'.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MarketplaceTermsScreen(),
          ),
        ),
      ),
    );
  }
}

/// Otvara uvjete korištenja (npr. iz dijaloga plaćanja).
void openMarketplaceTerms(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const MarketplaceTermsScreen()),
  );
}
