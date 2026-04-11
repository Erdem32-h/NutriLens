# NutriLens Monetization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add freemium monetization with RevenueCat subscriptions, AdMob ads, and server-side scan limits.

**Architecture:** Server-side scan limit control via Supabase RPC functions. RevenueCat manages subscriptions cross-platform. AdMob provides banner + rewarded ads for free tier. Abstract subscription interface allows future provider swaps.

**Tech Stack:** RevenueCat (purchases_flutter), Google AdMob (google_mobile_ads), Supabase Edge Functions + RPC, Riverpod providers.

**Design Doc:** `docs/plans/2026-04-04-monetization-design.md`

---

## Phase 1: Database & Backend

### Task 1: Supabase Migration — user_profiles + daily_scans tables

**Files:**
- Create: `supabase/migrations/20260404_add_monetization_tables.sql`

**Step 1: Write and apply migration**

Apply this migration via Supabase MCP `apply_migration`:

```sql
-- user_profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
  id                      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_tier       TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
  rc_customer_id          TEXT,
  subscription_expires_at TIMESTAMPTZ,
  daily_scan_limit        INT NOT NULL DEFAULT 2,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_read_own_profile" ON user_profiles
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "users_update_own_profile" ON user_profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Backfill profiles for existing users
INSERT INTO user_profiles (id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT id FROM user_profiles)
ON CONFLICT DO NOTHING;

-- daily_scans table
CREATE TABLE IF NOT EXISTS daily_scans (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scan_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  scan_count  INT NOT NULL DEFAULT 0,
  bonus_count INT NOT NULL DEFAULT 0,
  UNIQUE(user_id, scan_date)
);

ALTER TABLE daily_scans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_read_own_scans" ON daily_scans
  FOR SELECT USING (auth.uid() = user_id);

-- RPC: check_and_increment_scan
CREATE OR REPLACE FUNCTION check_and_increment_scan(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_tier TEXT;
  v_limit INT;
  v_count INT;
  v_bonus INT;
BEGIN
  SELECT subscription_tier, daily_scan_limit
    INTO v_tier, v_limit
    FROM user_profiles WHERE id = p_user_id;

  IF v_tier IS NULL THEN
    INSERT INTO user_profiles (id) VALUES (p_user_id);
    v_tier := 'free';
    v_limit := 2;
  END IF;

  IF v_tier = 'premium' THEN
    RETURN jsonb_build_object('allowed', true, 'remaining', -1, 'is_premium', true);
  END IF;

  INSERT INTO daily_scans (user_id, scan_date, scan_count, bonus_count)
    VALUES (p_user_id, CURRENT_DATE, 0, 0)
    ON CONFLICT (user_id, scan_date) DO NOTHING;

  SELECT scan_count, bonus_count INTO v_count, v_bonus
    FROM daily_scans WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;

  IF v_count < v_limit + v_bonus THEN
    UPDATE daily_scans SET scan_count = scan_count + 1
      WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;
    RETURN jsonb_build_object(
      'allowed', true,
      'remaining', v_limit + v_bonus - v_count - 1,
      'is_premium', false
    );
  END IF;

  RETURN jsonb_build_object('allowed', false, 'remaining', 0, 'is_premium', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: grant_bonus_scan
CREATE OR REPLACE FUNCTION grant_bonus_scan(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_bonus INT;
BEGIN
  INSERT INTO daily_scans (user_id, scan_date, scan_count, bonus_count)
    VALUES (p_user_id, CURRENT_DATE, 0, 0)
    ON CONFLICT (user_id, scan_date) DO NOTHING;

  SELECT bonus_count INTO v_bonus
    FROM daily_scans WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;

  IF v_bonus >= 3 THEN
    RETURN jsonb_build_object('granted', false, 'reason', 'max_bonus_reached');
  END IF;

  UPDATE daily_scans SET bonus_count = bonus_count + 1
    WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;

  RETURN jsonb_build_object('granted', true, 'bonus_remaining', 2 - v_bonus);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Step 2: Verify migration**

Run SQL to verify:
```sql
SELECT * FROM user_profiles LIMIT 1;
SELECT check_and_increment_scan('<existing_user_id>');
```

**Step 3: Commit**

```bash
git add supabase/migrations/20260404_add_monetization_tables.sql
git commit -m "feat: add user_profiles and daily_scans tables with RPC functions"
```

---

### Task 2: RevenueCat Webhook Edge Function

**Files:**
- Create: `supabase/functions/rc-webhook/index.ts`

**Step 1: Write the Edge Function**

```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RC_WEBHOOK_AUTH_KEY = Deno.env.get("RC_WEBHOOK_AUTH_KEY")!;

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Verify webhook auth
  const authHeader = req.headers.get("Authorization");
  if (authHeader !== `Bearer ${RC_WEBHOOK_AUTH_KEY}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const body = await req.json();
  const event = body.event;
  const appUserId = event?.app_user_id;

  if (!appUserId) {
    return new Response("Missing app_user_id", { status: 400 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const eventType = event.type;
  const expiresAt = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;

  let tier = "free";
  let expiresDate: string | null = null;

  switch (eventType) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
    case "UNCANCELLATION":
      tier = "premium";
      expiresDate = expiresAt;
      break;
    case "CANCELLATION":
      // Still premium until expiration
      tier = "premium";
      expiresDate = expiresAt;
      break;
    case "EXPIRATION":
    case "BILLING_ISSUE":
      tier = "free";
      expiresDate = null;
      break;
    default:
      return new Response(JSON.stringify({ status: "ignored", eventType }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
  }

  const { error } = await supabase
    .from("user_profiles")
    .update({
      subscription_tier: tier,
      subscription_expires_at: expiresDate,
      updated_at: new Date().toISOString(),
    })
    .eq("id", appUserId);

  if (error) {
    console.error("Update error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({ status: "ok", tier, appUserId }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
});
```

**Step 2: Deploy Edge Function**

Use Supabase MCP `deploy_edge_function` to deploy `rc-webhook`.

**Step 3: Add RC_WEBHOOK_AUTH_KEY secret**

Add secret via Supabase Dashboard → Edge Functions → Secrets.

**Step 4: Commit**

```bash
git add supabase/functions/rc-webhook/
git commit -m "feat: add RevenueCat webhook edge function"
```

---

## Phase 2: Flutter Core Services

### Task 3: Add Dependencies

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add packages**

Add under `dependencies:`:
```yaml
  # Monetization
  purchases_flutter: ^8.0.0
  google_mobile_ads: ^5.3.0
```

**Step 2: Install**

Run: `flutter pub get`

**Step 3: Platform config — Android**

Modify `android/app/src/main/AndroidManifest.xml` — add inside `<application>`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="${ADMOB_APP_ID}"/>
```

Modify `android/app/build.gradle` — add in `defaultConfig`:
```groovy
manifestPlaceholders["ADMOB_APP_ID"] = project.hasProperty('ADMOB_APP_ID')
    ? project.property('ADMOB_APP_ID')
    : 'ca-app-pub-3940256099942544~3347511713'  // test ID
```

**Step 4: Platform config — iOS**

Modify `ios/Runner/Info.plist` — add:
```xml
<key>GADApplicationIdentifier</key>
<string>$(ADMOB_APP_ID)</string>
<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
</array>
```

**Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/ ios/
git commit -m "feat: add purchases_flutter and google_mobile_ads dependencies"
```

---

### Task 4: Ad Constants & Service

**Files:**
- Create: `lib/core/constants/ad_constants.dart`
- Create: `lib/core/services/ad_service.dart`

**Step 1: Create ad_constants.dart**

```dart
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
```

**Step 2: Create ad_service.dart**

```dart
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
```

**Step 3: Commit**

```bash
git add lib/core/constants/ad_constants.dart lib/core/services/ad_service.dart
git commit -m "feat: add AdMob constants and ad service"
```

---

### Task 5: Subscription Service (RevenueCat)

**Files:**
- Create: `lib/core/services/subscription_service.dart`

**Step 1: Create subscription_service.dart**

```dart
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum SubscriptionTier { free, premium }

class SubscriptionStatus {
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final String? managementUrl;

  const SubscriptionStatus({
    required this.tier,
    this.expiresAt,
    this.managementUrl,
  });

  bool get isPremium => tier == SubscriptionTier.premium;

  static const free = SubscriptionStatus(tier: SubscriptionTier.free);
}

abstract interface class SubscriptionService {
  Future<void> initialize();
  Future<void> logIn(String userId);
  Future<void> logOut();
  Future<SubscriptionStatus> getStatus();
  Future<List<Package>> getOfferings();
  Future<bool> purchase(Package package);
  Future<bool> restorePurchases();
  Stream<SubscriptionStatus> get statusStream;
}

final class RevenueCatSubscriptionService implements SubscriptionService {
  static const _apiKeyAndroid = String.fromEnvironment('RC_API_KEY_ANDROID');
  static const _apiKeyIos = String.fromEnvironment('RC_API_KEY_IOS');
  static const _entitlementId = 'premium';

  @override
  Future<void> initialize() async {
    final apiKey = defaultTargetPlatform == TargetPlatform.android
        ? _apiKeyAndroid
        : _apiKeyIos;

    if (apiKey.isEmpty) {
      debugPrint('[RevenueCat] No API key — running in mock mode');
      return;
    }

    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);
    debugPrint('[RevenueCat] Configured');
  }

  @override
  Future<void> logIn(String userId) async {
    try {
      await Purchases.logIn(userId);
      debugPrint('[RevenueCat] Logged in as $userId');
    } catch (e) {
      debugPrint('[RevenueCat] Login error: $e');
    }
  }

  @override
  Future<void> logOut() async {
    try {
      if (await Purchases.isAnonymous == false) {
        await Purchases.logOut();
      }
    } catch (e) {
      debugPrint('[RevenueCat] Logout error: $e');
    }
  }

  @override
  Future<SubscriptionStatus> getStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _mapCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('[RevenueCat] getStatus error: $e');
      return SubscriptionStatus.free;
    }
  }

  @override
  Future<List<Package>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (e) {
      debugPrint('[RevenueCat] getOfferings error: $e');
      return [];
    }
  }

  @override
  Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo.entitlements
          .all[_entitlementId]?.isActive ?? false;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      debugPrint('[RevenueCat] Purchase error: $e');
      return false;
    } catch (e) {
      debugPrint('[RevenueCat] Purchase error: $e');
      return false;
    }
  }

  @override
  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.all[_entitlementId]?.isActive ?? false;
    } catch (e) {
      debugPrint('[RevenueCat] Restore error: $e');
      return false;
    }
  }

  @override
  Stream<SubscriptionStatus> get statusStream {
    return Purchases.customerInfoStream.map(_mapCustomerInfo);
  }

  SubscriptionStatus _mapCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.all[_entitlementId];
    if (entitlement != null && entitlement.isActive) {
      return SubscriptionStatus(
        tier: SubscriptionTier.premium,
        expiresAt: entitlement.expirationDate != null
            ? DateTime.tryParse(entitlement.expirationDate!)
            : null,
        managementUrl: info.managementURL,
      );
    }
    return SubscriptionStatus.free;
  }
}
```

**Step 2: Commit**

```bash
git add lib/core/services/subscription_service.dart
git commit -m "feat: add RevenueCat subscription service with abstract interface"
```

---

### Task 6: Scan Limit Service

**Files:**
- Create: `lib/core/services/scan_limit_service.dart`

**Step 1: Create scan_limit_service.dart**

```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanCheckResult {
  final bool allowed;
  final int remaining;
  final bool isPremium;

  const ScanCheckResult({
    required this.allowed,
    required this.remaining,
    required this.isPremium,
  });

  factory ScanCheckResult.fromJson(Map<String, dynamic> json) {
    return ScanCheckResult(
      allowed: json['allowed'] as bool? ?? false,
      remaining: json['remaining'] as int? ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }

  /// Premium users or fallback when server unreachable
  static const unlimited = ScanCheckResult(
    allowed: true,
    remaining: -1,
    isPremium: true,
  );
}

class BonusScanResult {
  final bool granted;
  final int bonusRemaining;
  final String? reason;

  const BonusScanResult({
    required this.granted,
    this.bonusRemaining = 0,
    this.reason,
  });

  factory BonusScanResult.fromJson(Map<String, dynamic> json) {
    return BonusScanResult(
      granted: json['granted'] as bool? ?? false,
      bonusRemaining: json['bonus_remaining'] as int? ?? 0,
      reason: json['reason'] as String?,
    );
  }
}

class ScanLimitService {
  final SupabaseClient _client;

  const ScanLimitService(this._client);

  Future<ScanCheckResult> checkAndIncrement() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const ScanCheckResult(allowed: false, remaining: 0, isPremium: false);
    }

    try {
      final response = await _client.rpc(
        'check_and_increment_scan',
        params: {'p_user_id': userId},
      );
      return ScanCheckResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ScanLimit] RPC error: $e');
      // Graceful fallback: allow scan on network error
      return ScanCheckResult.unlimited;
    }
  }

  Future<BonusScanResult> grantBonusScan() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const BonusScanResult(granted: false, reason: 'not_authenticated');
    }

    try {
      final response = await _client.rpc(
        'grant_bonus_scan',
        params: {'p_user_id': userId},
      );
      return BonusScanResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ScanLimit] Bonus RPC error: $e');
      return const BonusScanResult(granted: false, reason: 'network_error');
    }
  }
}
```

**Step 2: Commit**

```bash
git add lib/core/services/scan_limit_service.dart
git commit -m "feat: add scan limit service with Supabase RPC"
```

---

### Task 7: Monetization Providers

**Files:**
- Create: `lib/core/providers/monetization_provider.dart`

**Step 1: Create monetization_provider.dart**

```dart
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
  return service.statusStream;
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
  ref.onDispose(() => service.dispose());
  return service;
});
```

**Step 2: Commit**

```bash
git add lib/core/providers/monetization_provider.dart
git commit -m "feat: add monetization Riverpod providers"
```

---

### Task 8: App Initialization

**Files:**
- Modify: `lib/bootstrap.dart`

**Step 1: Add RevenueCat + AdMob initialization**

In `bootstrap()`, after Supabase initialization, add:

```dart
import '../core/services/ad_service.dart';
import '../core/services/subscription_service.dart';

// After Supabase init:

// Initialize RevenueCat
final subscriptionService = RevenueCatSubscriptionService();
await subscriptionService.initialize();

// Link auth to RevenueCat
final currentUser = Supabase.instance.client.auth.currentUser;
if (currentUser != null) {
  await subscriptionService.logIn(currentUser.id);
}

// Initialize AdMob
await AdService.initialize();
```

**Step 2: Commit**

```bash
git add lib/bootstrap.dart
git commit -m "feat: initialize RevenueCat and AdMob in bootstrap"
```

---

## Phase 3: UI — Premium Features

### Task 9: Ad Banner Widget

**Files:**
- Create: `lib/core/widgets/ad_banner_widget.dart`

**Step 1: Create ad_banner_widget.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_constants.dart';
import '../providers/monetization_provider.dart';

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

  void _loadAd() {
    final adSize = AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      MediaQuery.of(context).size.width.truncate(),
    );

    if (adSize == null) return;

    _bannerAd = BannerAd(
      adUnitId: AdConstants.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
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

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/core/widgets/ad_banner_widget.dart
git commit -m "feat: add conditional AdMob banner widget"
```

---

### Task 10: Scan Limit Sheet

**Files:**
- Create: `lib/features/premium/presentation/widgets/scan_limit_sheet.dart`

**Step 1: Create scan_limit_sheet.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/theme/app_colors.dart';

class ScanLimitSheet extends ConsumerWidget {
  const ScanLimitSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ScanLimitSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final adService = ref.read(adServiceProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Icon(Icons.qr_code_scanner, size: 48, color: colors.warning),
          const SizedBox(height: 16),

          // Title
          Text(
            'Günlük Tarama Hakkın Doldu',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            'Premium üyelikle sınırsız tarama yapabilirsin.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Premium button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context, false);
                context.push('/paywall');
              },
              icon: const Icon(Icons.star),
              label: const Text("Premium'a Geç"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Rewarded ad button
          if (adService.isRewardedAdReady)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final rewarded = await adService.showRewardedAd();
                  if (rewarded && context.mounted) {
                    final scanLimitService = ref.read(scanLimitServiceProvider);
                    final result = await scanLimitService.grantBonusScan();
                    if (result.granted && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  }
                },
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Reklam İzle → +1 Tarama'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          const SizedBox(height: 8),

          // Close
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/premium/presentation/widgets/scan_limit_sheet.dart
git commit -m "feat: add scan limit bottom sheet with premium upsell"
```

---

### Task 11: Paywall Screen

**Files:**
- Create: `lib/features/premium/presentation/screens/paywall_screen.dart`
- Modify: `lib/config/router/app_router.dart` — add `/paywall` route
- Modify: `lib/config/router/route_names.dart` — add `paywall` constant

**Step 1: Create paywall_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/theme/app_colors.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<Package> _packages = [];
  bool _loading = true;
  bool _purchasing = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final service = ref.read(subscriptionServiceProvider);
    final packages = await service.getOfferings();
    if (mounted) {
      setState(() {
        _packages = packages;
        _loading = false;
        // Default to annual if available
        final annualIdx = packages.indexWhere(
          (p) => p.packageType == PackageType.annual,
        );
        if (annualIdx >= 0) _selectedIndex = annualIdx;
      });
    }
  }

  Future<void> _purchase() async {
    if (_packages.isEmpty || _purchasing) return;
    setState(() => _purchasing = true);

    final service = ref.read(subscriptionServiceProvider);
    final success = await service.purchase(_packages[_selectedIndex]);

    if (mounted) {
      setState(() => _purchasing = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium aktif! 🎉')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _restore() async {
    final service = ref.read(subscriptionServiceProvider);
    final success = await service.restorePurchases();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Abonelik geri yüklendi!'
              : 'Aktif abonelik bulunamadı.'),
        ),
      );
      if (success) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        actions: [
          TextButton(
            onPressed: _restore,
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Hero
                  Icon(Icons.star, size: 64, color: colors.warning),
                  const SizedBox(height: 16),
                  Text(
                    'NutriLens Premium',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Features
                  _FeatureTile(icon: Icons.all_inclusive, text: 'Sınırsız tarama'),
                  _FeatureTile(icon: Icons.block, text: 'Reklamsız deneyim'),
                  _FeatureTile(icon: Icons.smart_toy, text: 'Sınırsız AI tarama'),
                  _FeatureTile(icon: Icons.support_agent, text: 'Öncelikli destek'),
                  const SizedBox(height: 32),

                  // Package cards
                  ..._packages.asMap().entries.map((entry) {
                    final i = entry.key;
                    final pkg = entry.value;
                    final isSelected = i == _selectedIndex;
                    final isAnnual = pkg.packageType == PackageType.annual;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = i),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : colors.textSecondary.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: i,
                              groupValue: _selectedIndex,
                              onChanged: (v) =>
                                  setState(() => _selectedIndex = v!),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isAnnual ? 'Yıllık' : 'Aylık',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      if (isAnnual) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.success
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '%40 tasarruf',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: colors.success,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pkg.storeProduct.priceString,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Purchase button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _purchasing ? null : _purchase,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _purchasing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Devam Et',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Legal
                  Text(
                    'Abonelik otomatik yenilenir. İstediğin zaman iptal edebilirsin.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
```

**Step 2: Add route**

In `app_router.dart`, add outside ShellRoute (next to product detail routes):
```dart
GoRoute(
  path: '/paywall',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) => const PaywallScreen(),
),
```

In `route_names.dart`:
```dart
static const String paywall = 'paywall';
```

**Step 3: Commit**

```bash
git add lib/features/premium/ lib/config/router/
git commit -m "feat: add paywall screen with plan selection and route"
```

---

## Phase 4: Integration

### Task 12: Scanner Screen — Scan Limit Check

**Files:**
- Modify: `lib/features/scanner/presentation/screens/scanner_screen.dart`

**Step 1: Add scan limit check before navigation**

Import providers and scan limit sheet. Wrap the navigation calls in `_onDetect` and `_captureForAi` with a scan check:

In `_onDetect` (barcode scan), before `context.push('/product/$value')` (~line 83):
```dart
// Check scan limit
final scanLimitService = ref.read(scanLimitServiceProvider);
final result = await scanLimitService.checkAndIncrement();
if (!result.allowed) {
  if (mounted) {
    final granted = await ScanLimitSheet.show(context);
    if (!granted) {
      _isNavigating = false;
      return;
    }
  } else {
    return;
  }
}
```

Apply same pattern in `_captureForAi`, before `context.push('/food-result', ...)` (~line 110).

**Step 2: Commit**

```bash
git add lib/features/scanner/presentation/screens/scanner_screen.dart
git commit -m "feat: add scan limit check to scanner screen"
```

---

### Task 13: App Shell — Banner Ad

**Files:**
- Modify: `lib/features/app_shell/app_shell_screen.dart`

**Step 1: Add AdBannerWidget above bottom nav**

Wrap the Scaffold body in a Column and add the banner between body and bottom nav:

```dart
body: Column(
  children: [
    Expanded(child: child),
    const AdBannerWidget(),
  ],
),
```

**Step 2: Commit**

```bash
git add lib/features/app_shell/app_shell_screen.dart
git commit -m "feat: add banner ad to app shell for free users"
```

---

### Task 14: Profile Screen — Subscription Section

**Files:**
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart`

**Step 1: Add subscription section**

After health filters section, add a "Premium" section:

```dart
// Subscription section
_SectionLabel(text: 'Abonelik'),
Consumer(builder: (context, ref, _) {
  final isPremium = ref.watch(isPremiumProvider);
  if (isPremium) {
    return _SettingsTile(
      icon: Icons.star,
      title: 'Premium Aktif',
      trailing: TextButton(
        onPressed: () {
          // Open store subscription management
        },
        child: const Text('Yönet'),
      ),
    );
  }
  return _SettingsTile(
    icon: Icons.star_outline,
    title: "Premium'a Geç",
    subtitle: 'Sınırsız tarama, reklamsız',
    onTap: () => context.push('/paywall'),
  );
}),
```

Also add a tier badge to the user header card.

**Step 2: Commit**

```bash
git add lib/features/profile/presentation/screens/profile_screen.dart
git commit -m "feat: add subscription section to profile screen"
```

---

### Task 15: Pre-load Rewarded Ads

**Files:**
- Modify: `lib/features/app_shell/app_shell_screen.dart`

**Step 1: Pre-load rewarded ad on app start**

In AppShellScreen's initState or build:
```dart
@override
void initState() {
  super.initState();
  // Pre-load rewarded ad for scan limit flow
  final adService = ref.read(adServiceProvider);
  adService.loadRewardedAd();
}
```

**Step 2: Commit**

```bash
git add lib/features/app_shell/app_shell_screen.dart
git commit -m "feat: pre-load rewarded ad on app start"
```

---

### Task 16: Auth ↔ RevenueCat Sync

**Files:**
- Modify: `lib/features/auth/presentation/providers/auth_provider.dart`

**Step 1: Sync auth state with RevenueCat**

In `AuthNotifier.signInWithEmail`, `signInWithGoogle`, `signInWithApple` — after successful auth:
```dart
final subscriptionService = ref.read(subscriptionServiceProvider);
await subscriptionService.logIn(user.id);
```

In `signOut`:
```dart
final subscriptionService = ref.read(subscriptionServiceProvider);
await subscriptionService.logOut();
```

**Step 2: Commit**

```bash
git add lib/features/auth/presentation/providers/auth_provider.dart
git commit -m "feat: sync auth state with RevenueCat"
```

---

## Phase 5: Build & Verify

### Task 17: Build and Test

**Step 1: Run analyzer**

```bash
flutter analyze
```
Fix any issues.

**Step 2: Build Android**

```bash
flutter build apk --debug
```

**Step 3: Build iOS (if on Mac)**

```bash
flutter build ios --no-codesign
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete monetization integration (RevenueCat + AdMob + scan limits)"
```

---

## Execution Checklist

| # | Task | Phase |
|---|------|-------|
| 1 | Supabase migration (tables + RPCs) | Backend |
| 2 | RevenueCat webhook Edge Function | Backend |
| 3 | Add Flutter dependencies | Core |
| 4 | Ad constants & service | Core |
| 5 | Subscription service (RevenueCat) | Core |
| 6 | Scan limit service | Core |
| 7 | Monetization providers | Core |
| 8 | App initialization (bootstrap) | Core |
| 9 | Ad banner widget | UI |
| 10 | Scan limit sheet | UI |
| 11 | Paywall screen + route | UI |
| 12 | Scanner scan limit check | Integration |
| 13 | App shell banner ad | Integration |
| 14 | Profile subscription section | Integration |
| 15 | Pre-load rewarded ads | Integration |
| 16 | Auth ↔ RevenueCat sync | Integration |
| 17 | Build and verify | Verify |
