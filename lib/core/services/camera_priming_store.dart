import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/locale_provider.dart' show sharedPreferencesProvider;

/// Remembers whether the camera has ever come up on this install, which is
/// the only signal available for "has this user already granted camera
/// permission" without adding a permission plugin.
///
/// Why it exists: the OS prompt used to fire straight out of the scanner's
/// initState, so the user decided before anything explained why the camera
/// was wanted. Over 7 days that produced 101 devices answering "deny", 85 of
/// them at the very first ask — and 62 of those never got a working camera
/// afterwards, which is 18% of everyone who opened the scanner. The recovery
/// paths already in the screen (retry, return-from-Settings self-heal) win
/// back the other 39, so the remaining loss can only be addressed before the
/// question is asked, not after.
///
/// Deliberately keyed on "the camera worked" rather than "the sheet was
/// shown": a user who declines keeps seeing the explanation on their next
/// visit, which is their way back, while a user who grants never sees it
/// again. The flag is set from the same place that reports `scan_camera_ready`
/// so the two can never disagree.
class CameraPrimingStore {
  static const _kCameraWorkedKey = 'scanner.camera_worked_v1';

  final SharedPreferences _prefs;

  const CameraPrimingStore(this._prefs);

  /// True until the camera has successfully started at least once.
  ///
  /// Note for the 1.2.4 rollout: users who already granted the permission in
  /// an earlier version have no flag yet, so they see the sheet once. That is
  /// the accepted cost of not adding `permission_handler` — one sheet, one
  /// tap, and never again once their camera comes up.
  bool get needsRationale => !(_prefs.getBool(_kCameraWorkedKey) ?? false);

  Future<void> markCameraWorked() async {
    if (_prefs.getBool(_kCameraWorkedKey) ?? false) return;
    await _prefs.setBool(_kCameraWorkedKey, true);
  }
}

final cameraPrimingStoreProvider = Provider<CameraPrimingStore>((ref) {
  return CameraPrimingStore(ref.watch(sharedPreferencesProvider));
});
