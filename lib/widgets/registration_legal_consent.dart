import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../features/legal/marketplace_terms_screen.dart';
import '../features/legal/privacy_policy_screen.dart';

/// Obavezna suglasnost pri registraciji (uvjeti tržnice + politika privatnosti).
class RegistrationLegalConsent extends StatelessWidget {
  const RegistrationLegalConsent({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 13,
      height: 1.4,
      color: Colors.grey.shade800,
    );
    final linkStyle = baseStyle.copyWith(
      color: Colors.green.shade800,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: CheckboxListTile(
        value: value,
        onChanged: (checked) => onChanged(checked ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        title: RichText(
          text: TextSpan(
            style: baseStyle,
            children: [
              TextSpan(text: '${'registration_legal_consent_prefix'.tr()} '),
              TextSpan(
                text: 'registration_legal_terms_link'.tr(),
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => openMarketplaceTerms(context),
              ),
              TextSpan(text: ' ${'registration_legal_and'.tr()} '),
              TextSpan(
                text: 'registration_legal_privacy_link'.tr(),
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => openPrivacyPolicy(context),
              ),
              TextSpan(text: '.'),
            ],
          ),
        ),
      ),
    );
  }
}
