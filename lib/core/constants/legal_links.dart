abstract final class LegalLinks {
  // Default = live GitHub Pages URL. If Codemagic provides PRIVACY_POLICY_URL
  // via --dart-define (e.g. a custom domain later), that wins.
  static const privacyPolicy = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://erdem32-h.github.io/NutriLens/privacy.html',
  );

  // Apple's Standard EULA — works for both iOS and Android paywall copy.
  static const termsOfUse = String.fromEnvironment(
    'TERMS_OF_USE_URL',
    defaultValue:
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  );
}
