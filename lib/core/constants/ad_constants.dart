import 'dart:io';

import 'package:flutter/foundation.dart';

abstract final class AdConstants {
  // Google test ad unit IDs
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  // Production IDs from .env (set these when AdMob account is ready)
  static const _prodAppIos = String.fromEnvironment('ADMOB_APP_ID_IOS');
  static const _prodBannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
  );
  static const _prodBannerIos = String.fromEnvironment('ADMOB_BANNER_IOS');
  static const _prodRewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
  );
  static const _prodRewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS');

  /// Ads are enabled in debug (test ads, for development) and in release ONLY
  /// when a real AdMob unit is configured for the platform via --dart-define.
  /// Releases must NEVER serve Google's test ad units — that violates AdMob
  /// policy (risking account suspension) and looks broken to users. So when
  /// production IDs are absent, ads stay off entirely rather than falling back
  /// to test units.
  static bool get isAdMobEnabled {
    if (kDebugMode) return true;
    if (Platform.isAndroid) {
      return _prodBannerAndroid.isNotEmpty || _prodRewardedAndroid.isNotEmpty;
    }
    return _prodAppIos.isNotEmpty &&
        (_prodBannerIos.isNotEmpty || _prodRewardedIos.isNotEmpty);
  }

  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid ? _testBannerAndroid : _testBannerIos;
    }
    // Release: real unit only — no test fallback. (When unconfigured this is
    // empty, but [isAdMobEnabled] is false then, so it's never requested.)
    return Platform.isAndroid ? _prodBannerAndroid : _prodBannerIos;
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid ? _testRewardedAndroid : _testRewardedIos;
    }
    return Platform.isAndroid ? _prodRewardedAndroid : _prodRewardedIos;
  }

  static const int maxBonusScansPerDay = 3;
}
