import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_constants.dart';

class AdService {
  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  bool get isRewardedAdReady => _isRewardedAdReady;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    debugPrint('[AdService] MobileAds initialized');
  }

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          debugPrint('[AdService] Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdReady = false;
          debugPrint('[AdService] Rewarded ad failed: ${error.message}');
        },
      ),
    );
  }

  Future<bool> showRewardedAd() async {
    if (!_isRewardedAdReady || _rewardedAd == null) return false;

    var rewarded = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isRewardedAdReady = false;
        loadRewardedAd(); // Pre-load next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isRewardedAdReady = false;
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
      },
    );

    return rewarded;
  }

  void dispose() {
    _rewardedAd?.dispose();
  }
}
