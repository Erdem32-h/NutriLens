import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/locale_provider.dart';

/// Lifetime scan budget for guest (un-registered) users. Five was
/// picked deliberately to align with the "after-5-scans soft prompt"
/// product decision: scans 1-4 are silent, the 5th surfaces a soft
/// nudge, the 6th hard-blocks and pushes registration. Counter lives
/// in SharedPreferences and resets only on app uninstall, so the abuse
/// surface is intentionally small (a determined user reinstalls and
/// scrubs their device — not a realistic conversion threat).
///
/// Exposed as a [Notifier] so widgets watching the budget (e.g. the
/// scanner-screen badge) rebuild automatically after each increment.
class GuestScanCounter extends Notifier<int> {
  static const _kCountKey = 'guest.scan_count_v1';

  /// Set the first time the server's device-keyed count is read on this
  /// install. Separate from the count itself because a count of zero is
  /// ambiguous — see [hasServerBaseline].
  static const _kBaselineKey = 'guest.server_baseline_v1';

  /// Set once the one-off offline courtesy scan has been used.
  static const _kGoodwillKey = 'guest.offline_goodwill_spent_v1';
  static const int lifetimeLimit = 5;

  late SharedPreferences _prefs;
  bool _hasServerBaseline = false;
  bool _goodwillSpent = false;

  @override
  int build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    _hasServerBaseline = _prefs.getBool(_kBaselineKey) ?? false;
    _goodwillSpent = _prefs.getBool(_kGoodwillKey) ?? false;
    return _prefs.getInt(_kCountKey) ?? 0;
  }

  int get count => state;

  /// Whether the server's authoritative count has ever been read on this
  /// install. Until it has, a local count of zero proves nothing: it is what
  /// a first launch AND an app-data wipe both look like. Callers must not
  /// spend from the local counter while this is false — see
  /// `decideGuestScan` in `guest_scan_gate.dart`.
  bool get hasServerBaseline => _hasServerBaseline;

  /// Whether the one-off offline courtesy scan is still available. Only
  /// consulted while [hasServerBaseline] is false — once the server has been
  /// heard from, its count governs and courtesy is irrelevant.
  bool get goodwillAvailable => !_goodwillSpent;

  /// Burns the courtesy scan. Deliberately independent of [count], which
  /// mirrors the server: nothing here should look like server-granted budget.
  Future<void> spendGoodwill() async {
    if (_goodwillSpent) return;
    _goodwillSpent = true;
    await _prefs.setBool(_kGoodwillKey, true);
  }

  int get remaining {
    final r = lifetimeLimit - state;
    return r < 0 ? 0 : r;
  }

  /// True if the user still has scans left in their guest budget.
  /// False at exactly [lifetimeLimit] consumed scans — the caller
  /// should show the hard-block register sheet.
  bool get canScan => state < lifetimeLimit;

  /// Called after a successful scan check. Returns the new count so
  /// the caller can decide whether to fire the 5th-scan soft prompt.
  Future<int> increment() async {
    final next = state + 1;
    await _prefs.setInt(_kCountKey, next);
    state = next;
    return next;
  }

  /// Reconcile the local fallback counter with the server's authoritative
  /// device-keyed count. Only ever raises the local count (the server is the
  /// floor, never a way to gift scans back), so a cache/data clear that reset
  /// the local counter to 0 gets corrected to the real server total.
  Future<void> syncFromServer(int serverCount) async {
    // Recorded before the early return below: hearing from the server at all
    // is what makes the local counter trustworthy afterwards, even when the
    // server's count matches what we already had and nothing needs writing.
    if (!_hasServerBaseline) {
      _hasServerBaseline = true;
      await _prefs.setBool(_kBaselineKey, true);
    }
    final clamped = serverCount.clamp(0, lifetimeLimit);
    if (clamped <= state) return;
    await _prefs.setInt(_kCountKey, clamped);
    state = clamped;
  }

  /// Wipes the counter. Called from the migration flow once a guest
  /// has registered — the new authenticated user starts with their
  /// server-side daily limit instead of inheriting the local cap.
  Future<void> reset() async {
    await _prefs.remove(_kCountKey);
    // The baseline goes with it: it describes a guest identity that no longer
    // applies. If this device ever falls back to guest mode it must re-earn
    // the server's answer rather than inherit a stale licence to spend.
    await _prefs.remove(_kBaselineKey);
    await _prefs.remove(_kGoodwillKey);
    _hasServerBaseline = false;
    _goodwillSpent = false;
    state = 0;
  }
}

final guestScanCounterProvider = NotifierProvider<GuestScanCounter, int>(
  GuestScanCounter.new,
);
