/// Pravni linkovi — postavi [PRIVACY_POLICY_URL] u secrets.local.json ili --dart-define.
class LegalConfig {
  LegalConfig._();

  static const privacyPolicyWebUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: '',
  );

  static bool get hasHostedPrivacyPolicy =>
      privacyPolicyWebUrl.trim().isNotEmpty;

  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'myfarmer.network@gmail.com',
  );
}
