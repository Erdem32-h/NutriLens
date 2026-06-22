import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../constants/ad_constants.dart';
import '../services/ad_service.dart';
import '../services/device_id_service.dart';
import '../services/guest_scan_limit_service.dart';
import '../services/scan_limit_service.dart';
import '../services/subscription_service.dart';
import 'locale_provider.dart';

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

/// Keeps RevenueCat associated with the signed-in Supabase user whenever it
/// changes — crucially on cold-start session restore, where previously only an
/// interactive sign-in called `logIn`. A restored session otherwise left RC
/// anonymous, so a premium entitlement wasn't seen until a manual re-login.
/// `logIn` is idempotent and swallows its own errors; the resulting RevenueCat
/// customer-info update flows back through [subscriptionStatusProvider]. Kept
/// alive by [isPremiumProvider], so it runs from app start.
final _revenueCatUserSyncProvider = Provider<void>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId != null) {
    // Fire-and-forget: the entitlement arrives asynchronously via the
    // customer-info listener inside subscriptionStatusProvider.
    service.logIn(userId);
  }
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
  // Ensure RevenueCat is logged in as the current user (covers cold-start
  // session restore, not just interactive sign-in).
  ref.watch(_revenueCatUserSyncProvider);
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

final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return DeviceIdService(ref.watch(sharedPreferencesProvider));
});

/// Server-authoritative guest scan budget (device-hash keyed). Survives an
/// app cache/data clear, unlike the local [GuestScanCounter] which is now a
/// fallback for offline use.
final guestScanLimitServiceProvider = Provider<GuestScanLimitService>((ref) {
  return GuestScanLimitService(
    Supabase.instance.client,
    ref.watch(deviceIdServiceProvider),
  );
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
