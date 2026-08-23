import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_constants.dart';
import '../providers/monetization_provider.dart';

/// Space reserved under the banner for the scanner button's overhang.
///
/// The button is 72px tall and anchored 30px up from the bottom of a 96px
/// nav bar, so it pokes ~40px above the bar once its label is counted. This
/// is that overhang plus a little air.
const double kAdBannerScannerClearance = 44;

class AdBannerWidget extends ConsumerStatefulWidget {
  const AdBannerWidget({super.key});

  @override
  ConsumerState<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends ConsumerState<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) _loadAd();
  }

  Future<void> _loadAd() async {
    if (!AdConstants.isAdMobEnabled) return;

    final adSize = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      MediaQuery.of(context).size.width.truncate(),
    );

    if (adSize == null) return;

    _bannerAd = BannerAd(
      adUnitId: AdConstants.bannerAdUnitId,
      size: adSize,
      request: AdConstants.adRequest,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('[AdBanner] Failed to load: ${error.message}');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);

    if (isPremium || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
        // Landing strip for the scanner button, which lifts above the nav bar
        // directly below this banner and would otherwise paint over it —
        // sloppy to look at, and AdMob requires that an ad not be obscured by
        // app UI. Lives here rather than in the shell so it costs nothing on
        // the screens (and the accounts) where no banner renders.
        const SizedBox(height: kAdBannerScannerClearance),
      ],
    );
  }
}
