import 'package:flutter/material.dart';

/// Where a subscription is actually cancelled.
///
/// Neither store lets an app cancel on the user's behalf — the platforms own
/// the billing relationship, and both require the app to hand the user off to
/// their own subscription page instead. So "cancel" in our UI can only ever
/// mean "open this".
///
/// RevenueCat gives us a per-customer `managementURL` that deep-links to the
/// exact subscription; these are the fallbacks for when it is null, which
/// happens before customer info has loaded and for entitlements with no store
/// purchase behind them.
abstract final class StoreLinks {
  static const _playSubscriptions =
      'https://play.google.com/store/account/subscriptions';
  static const _appStoreSubscriptions =
      'https://apps.apple.com/account/subscriptions';

  static String subscriptionsFor(TargetPlatform platform) {
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? _appStoreSubscriptions
        : _playSubscriptions;
  }
}
