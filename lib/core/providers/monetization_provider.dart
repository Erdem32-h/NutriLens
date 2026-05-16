import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../constants/ad_constants.dart';
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

/// Reads `user_profiles.subscription_tier` from Supabase. RevenueCat is the
/// primary source of truth for paying customers, but server-side admin
/// grants (manual upgrades, comp accounts, webhook backfills) must also
/// flip the UI to premium — otherwise the user keeps seeing "Premium'a Geç"
/// even though the scan-limit RPC already lets them through.
final supabasePremiumProvider = FutureProvider<bool>((ref) async {
  // Re-fetch when the signed-in user changes.
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return false;
  try {
    final row = await Supabase.instance.client
        .from('user_profiles')
        .select('subscription_tier, subscription_expires_at')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return false;
    final tier = row['subscription_tier'] as String?;
    if (tier != 'premium') return false;
    final expiresAt = row['subscription_expires_at'] as String?;
    if (expiresAt == null) return true; // open-ended grant
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return true;
    return expiry.isAfter(DateTime.now());
  } catch (_) {
    return false;
  }
});

final isPremiumProvider = Provider<bool>((ref) {
  final rcStatus = ref.watch(subscriptionStatusProvider);
  final rcPremium = rcStatus.whenOrNull(data: (s) => s.isPremium) ?? false;
  final dbPremium =
      ref.watch(supabasePremiumProvider).whenOrNull(data: (v) => v) ?? false;
  return rcPremium || dbPremium;
});

// ── Scan Limits ──

final scanLimitServiceProvider = Provider<ScanLimitService>((ref) {
  return ScanLimitService(Supabase.instance.client);
});

// ── Ads ──

final adServiceProvider = Provider<AdService>((ref) {
  final service = AdService();
  if (AdConstants.isAdMobEnabled) {
    service.loadRewardedAd();
  }
  ref.onDispose(() => service.dispose());
  return service;
});
