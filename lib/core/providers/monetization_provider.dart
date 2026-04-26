import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ad_service.dart';
import '../services/scan_limit_service.dart';
import '../services/subscription_service.dart';

// ── Subscription ──

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return RevenueCatSubscriptionService();
});

final subscriptionStatusProvider = StreamProvider<SubscriptionStatus>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return (() async* {
    yield await service.getStatus();
    yield* service.statusStream;
  })();
});

final isPremiumProvider = Provider<bool>((ref) {
  final status = ref.watch(subscriptionStatusProvider);
  return status.whenOrNull(data: (s) => s.isPremium) ?? false;
});

// ── Scan Limits ──

final scanLimitServiceProvider = Provider<ScanLimitService>((ref) {
  return ScanLimitService(Supabase.instance.client);
});

// ── Ads ──

final adServiceProvider = Provider<AdService>((ref) {
  final service = AdService();
  service.loadRewardedAd();
  ref.onDispose(() => service.dispose());
  return service;
});
