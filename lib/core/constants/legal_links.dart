abstract final class LegalLinks {
  static const privacyPolicy = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://www.nutrilens.app/privacy',
  );

  static const termsOfUse = String.fromEnvironment(
    'TERMS_OF_USE_URL',
    defaultValue:
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  );
}
