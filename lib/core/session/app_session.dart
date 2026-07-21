import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/locale_provider.dart';

/// High-level session state. The router and provider layer key off this
/// instead of asking Supabase directly — that way "guest" is a real,
/// observable state distinct from "logged out".
enum AppSessionState {
  /// No Supabase session and no guest-mode preference. The login screen
  /// is the only allowed destination.
  loggedOut,

  /// User explicitly tapped "Continue as guest". They get the full app
  /// experience minus cloud-only features. Their data lives under the
  /// [kGuestUserId] sentinel in local Drift tables.
  guest,

  /// Authenticated Supabase user. Real user id from [currentUserProvider].
  authenticated,
}

/// Sentinel user id used in local-only tables when the user is browsing
/// as a guest. We deliberately namespace it so a real Supabase UUID can
/// never collide with it.
const String kGuestUserId = 'guest-local';

const String _kGuestFlagKey = 'app.guest_mode_v1';

/// Set once the user has walked through (or skipped) the intro pages.
/// Written by the onboarding screen; read by the router to decide
/// whether a logged-out launch shows the intro or the login form.
const String kOnboardingSeenKey = 'onboarding_complete';

/// Reads SharedPreferences without throwing when the plugin failed to
/// initialise at boot. `sharedPreferencesProvider` deliberately throws
/// when un-overridden (see locale_provider), and main() only overrides
/// it when `SharedPreferences.getInstance()` succeeded. Session lookups
/// run inside the GoRouter redirect, where an exception surfaces as a
/// router failure rather than a caught error — so degrade to "no saved
/// preferences" instead of taking the whole navigation down.
SharedPreferences? _prefsOrNull(Ref ref) {
  try {
    return ref.watch(sharedPreferencesProvider);
  } catch (_) {
    return null;
  }
}

/// Resolves the current session state from auth + persistent guest flag.
final appSessionProvider = Provider<AppSessionState>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user != null) return AppSessionState.authenticated;

  final prefs = _prefsOrNull(ref);
  if (prefs?.getBool(_kGuestFlagKey) ?? false) {
    return AppSessionState.guest;
  }
  return AppSessionState.loggedOut;
});

/// False until the user has seen the intro pages at least once. Drives
/// the first-launch destination: a brand-new install gets the value
/// pitch instead of an email/password form it has no reason to fill in
/// yet. Defaults to `true` when preferences are unavailable so a broken
/// prefs plugin can never trap a returning user in the intro loop.
final hasSeenOnboardingProvider = Provider<bool>((ref) {
  final prefs = _prefsOrNull(ref);
  if (prefs == null) return true;
  return prefs.getBool(kOnboardingSeenKey) ?? false;
});

/// Effective user id to scope local Drift queries (history, meals,
/// favorites, blacklist). Authenticated users get their Supabase UUID;
/// guests get the [kGuestUserId] sentinel. Returns null only when the
/// user is logged out — callers should not be reading data in that
/// state (the router would have already redirected them to /login).
final effectiveUserIdProvider = Provider<String?>((ref) {
  final session = ref.watch(appSessionProvider);
  switch (session) {
    case AppSessionState.authenticated:
      return ref.watch(currentUserProvider)?.id;
    case AppSessionState.guest:
      return kGuestUserId;
    case AppSessionState.loggedOut:
      return null;
  }
});

/// Convenience flags for UI guards. `isGuest` is used by the profile
/// banner, "Save to cloud" CTAs, and the premium gate.
final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(appSessionProvider) == AppSessionState.guest;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(appSessionProvider) == AppSessionState.authenticated;
});

/// Mutates the persistent guest flag. Hold this from screens that need
/// to enter or exit guest mode.
class AppSessionController {
  final Ref _ref;
  final SharedPreferences _prefs;

  AppSessionController(this._ref, this._prefs);

  /// Mark the user as a guest. Persists across app launches until they
  /// either log in (auth state takes precedence) or call [exitGuestMode].
  Future<void> enterGuestMode() async {
    await _prefs.setBool(_kGuestFlagKey, true);
    _ref.invalidate(appSessionProvider);
  }

  /// Clear the guest flag. Called when the user logs in (the auth
  /// state would already cover them, but we don't want a stale flag
  /// hanging around) or when they sign out from a guest session.
  Future<void> exitGuestMode() async {
    await _prefs.remove(_kGuestFlagKey);
    _ref.invalidate(appSessionProvider);
  }

  /// Record that the intro pages have been shown, so later launches go
  /// straight to the app instead of replaying them.
  Future<void> completeOnboarding() async {
    await _prefs.setBool(kOnboardingSeenKey, true);
    _ref.invalidate(hasSeenOnboardingProvider);
  }
}

final appSessionControllerProvider = Provider<AppSessionController>((ref) {
  return AppSessionController(ref, ref.watch(sharedPreferencesProvider));
});
