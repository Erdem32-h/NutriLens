import 'package:flutter/foundation.dart';

/// A single funnel data point, queued on-device before being flushed to
/// Supabase in batches.
///
/// Deliberately dumb: no device hash, no user id, no app version. Those are
/// identical for every event in a batch, so [AnalyticsService] stamps them
/// once at flush time instead of copying them onto every queued row.
@immutable
class AnalyticsEvent {
  const AnalyticsEvent({
    required this.name,
    required this.sessionId,
    required this.occurredAt,
    this.props = const {},
  });

  /// Must satisfy `^[a-z][a-z0-9_]{2,63}$` — the server drops anything else.
  /// Use the constants in [FunnelEvents] rather than string literals.
  final String name;

  /// Groups the events of one app launch. Lets a query ask "of the sessions
  /// that opened the scanner, how many reached a product page" without
  /// conflating two separate launches by the same device.
  final String sessionId;

  /// Client clock at the moment the event happened, not the moment it was
  /// uploaded — an offline batch can be flushed hours later.
  final DateTime occurredAt;

  /// Small, non-identifying context. Never put user text, emails, or raw
  /// barcodes here; see [FunnelEvents] for what each event carries.
  final Map<String, Object?> props;

  Map<String, Object?> toJson() => {
    'event': name,
    'session_id': sessionId,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'props': props,
  };

  static AnalyticsEvent? tryFromJson(Map<String, Object?> json) {
    final name = json['event'];
    final sessionId = json['session_id'];
    final occurredAt = DateTime.tryParse(json['occurred_at'] as String? ?? '');
    if (name is! String || sessionId is! String || occurredAt == null) {
      return null;
    }
    final props = json['props'];
    return AnalyticsEvent(
      name: name,
      sessionId: sessionId,
      occurredAt: occurredAt,
      props: props is Map<String, Object?> ? props : const {},
    );
  }
}

/// The funnel vocabulary, in the order a healthy first session hits it.
///
/// These names are load-bearing: `analytics_funnel_steps` in the migration
/// maps them onto ordered steps. Renaming one here without updating that
/// view silently drops a step out of every report.
abstract final class FunnelEvents {
  // --- Launch ---------------------------------------------------------
  /// props: `first_launch` (bool), `session_state` (loggedOut|guest|authenticated)
  static const appOpened = 'app_opened';

  // --- Onboarding -----------------------------------------------------
  static const onboardingShown = 'onboarding_shown';

  /// props: `page` (int) — how far they got before leaving.
  static const onboardingPageViewed = 'onboarding_page_viewed';
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingSkipped = 'onboarding_skipped';

  // --- Entering a session ---------------------------------------------
  static const authScreenShown = 'auth_screen_shown';
  static const guestStarted = 'guest_started';
  static const registerStarted = 'register_started';
  static const registerSucceeded = 'register_succeeded';

  /// props: `reason` (short machine code, never the raw error text)
  static const registerFailed = 'register_failed';
  static const loginStarted = 'login_started';
  static const loginSucceeded = 'login_succeeded';

  /// props: `reason`
  static const loginFailed = 'login_failed';

  // --- Scanning -------------------------------------------------------
  /// props: `source` (nav|meals|products|widget|deeplink)
  static const scannerOpened = 'scanner_opened';

  /// The camera preview is actually live. The gap between this and
  /// [scannerOpened] is where a permission wall or a black preview hides —
  /// both of which look identical to "user opened the scanner and left" in
  /// any server-side table.
  static const scanCameraReady = 'scan_camera_ready';

  /// props: `reason` (permission_denied|unavailable|error), `mode`
  static const scanCameraFailed = 'scan_camera_failed';

  /// props: `mode` (barcode|food) — no barcode value, that would turn the
  /// table into a per-device consumption profile.
  static const scanBarcodeDetected = 'scan_barcode_detected';

  /// props: `source` (local|off|api|community|ocr) — which link of the
  /// lookup chain answered.
  static const scanLookupSucceeded = 'scan_lookup_succeeded';

  /// props: `reason` (not_found|network|limit|error)
  static const scanLookupFailed = 'scan_lookup_failed';

  /// props: `has_score` (bool)
  static const productViewed = 'product_viewed';

  // --- Activation -----------------------------------------------------
  static const favoriteAdded = 'favorite_added';

  /// props: `reason` (guest|error) — the user asked to favourite something
  /// and the app refused. Guests are refused silently (favourites are a
  /// Supabase-backed, auth-only feature), which is a live candidate
  /// explanation for the zero-favourites number and is worth separating
  /// from "nobody ever tried".
  static const favoriteBlocked = 'favorite_blocked';
  static const mealAdded = 'meal_added';
  static const productShared = 'product_shared';

  // --- Monetization ---------------------------------------------------
  /// props: `trigger` (scan_limit|profile|feature_gate)
  static const paywallShown = 'paywall_shown';
}
