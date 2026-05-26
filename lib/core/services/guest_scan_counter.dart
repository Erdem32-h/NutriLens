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
  static const int lifetimeLimit = 5;

  late SharedPreferences _prefs;

  @override
  int build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _prefs.getInt(_kCountKey) ?? 0;
  }

  int get count => state;

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

  /// Wipes the counter. Called from the migration flow once a guest
  /// has registered — the new authenticated user starts with their
  /// server-side daily limit instead of inheriting the local cap.
  Future<void> reset() async {
    await _prefs.remove(_kCountKey);
    state = 0;
  }
}

final guestScanCounterProvider = NotifierProvider<GuestScanCounter, int>(
  GuestScanCounter.new,
);
