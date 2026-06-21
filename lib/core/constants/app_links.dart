abstract final class AppLinks {
  /// Play Store listing — used in share captions. Overridable via dart-define
  /// so a future custom landing page or App Store link is an ops change.
  static const shareStoreUrl = String.fromEnvironment(
    'SHARE_STORE_URL',
    defaultValue:
        'https://play.google.com/store/apps/details?id=com.nutrilensapp.android',
  );
}
