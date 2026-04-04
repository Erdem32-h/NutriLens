import 'dart:io';

import 'package:flutter/foundation.dart';

abstract final class AdConstants {
  // Google test ad unit IDs
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  // Production IDs from .env (set these when AdMob account is ready)
  static const _prodBannerAndroid = String.fromEnvironment('ADMOB_BANNER_ANDROID');
  static const _prodBannerIos = String.fromEnvironment('ADMOB_BANNER_IOS');
  static const _prodRewardedAndroid = String.fromEnvironment('ADMOB_REWARDED_ANDROID');
  static const _prodRewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS');

  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid ? _testBannerAndroid : _testBannerIos;
    }
    return Platform.isAndroid
        ? (_prodBannerAndroid.isNotEmpty ? _prodBannerAndroid : _testBannerAndroid)
        : (_prodBannerIos.isNotEmpty ? _prodBannerIos : _testBannerIos);
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid ? _testRewardedAndroid : _testRewardedIos;
    }
    return Platform.isAndroid
        ? (_prodRewardedAndroid.isNotEmpty ? _prodRewardedAndroid : _testRewardedAndroid)
        : (_prodRewardedIos.isNotEmpty ? _prodRewardedIos : _testRewardedIos);
  }

  static const int maxBonusScansPerDay = 3;
}
