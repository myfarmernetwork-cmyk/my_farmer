import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal_config.dart';

/// Politika privatnosti — Play Store zahtijeva dostupnost u appu i/ili na webu.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    _PolicySection('privacy_controller_title', 'privacy_controller_body'),
    _PolicySection('privacy_data_title', 'privacy_data_body'),
    _PolicySection('privacy_purpose_title', 'privacy_purpose_body'),
    _PolicySection('privacy_location_title', 'privacy_location_body'),
    _PolicySection('privacy_third_parties_title', 'privacy_third_parties_body'),
    _PolicySection('privacy_retention_title', 'privacy_retention_body'),
    _PolicySection('privacy_rights_title', 'privacy_rights_body'),
    _PolicySection('privacy_security_title', 'privacy_security_body'),
    _PolicySection('privacy_contact_title', 'privacy_contact_body'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('privacy_policy_title'.tr()),
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined,
                          color: Colors.blue.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'privacy_policy_subtitle'.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'privacy_policy_intro'.tr(),
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (LegalConfig.hasHostedPrivacyPolicy) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openWebVersion(context),
                icon: const Icon(Icons.open_in_new),
                label: Text('privacy_policy_open_web'.tr()),
              ),
            ],
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
                _bodyForSection(section.bodyKey),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'privacy_policy_footer'.tr(),
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

  String _bodyForSection(String key) {
    if (key == 'privacy_contact_body') {
      return key.tr(namedArgs: {'email': LegalConfig.supportEmail});
    }
    return key.tr();
  }

  Future<void> _openWebVersion(BuildContext context) async {
    final uri = Uri.tryParse(LegalConfig.privacyPolicyWebUrl.trim());
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('privacy_policy_web_failed'.tr())),
        );
      }
    }
  }
}

class _PolicySection {
  const _PolicySection(this.titleKey, this.bodyKey);

  final String titleKey;
  final String bodyKey;
}

class ProfilePrivacyPolicyTile extends StatelessWidget {
  const ProfilePrivacyPolicyTile({super.key});

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
          backgroundColor: Colors.blue.shade50,
          child: Icon(Icons.privacy_tip_outlined, color: Colors.blue.shade800),
        ),
        title: Text(
          'privacy_policy_profile_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('privacy_policy_profile_subtitle'.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
        ),
      ),
    );
  }
}

void openPrivacyPolicy(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
  );
}
