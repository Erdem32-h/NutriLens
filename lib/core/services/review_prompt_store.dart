import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/locale_provider.dart' show sharedPreferencesProvider;

/// Decides when to ask the OS for an in-app store review.
///
/// Gated on a meal count rather than the first save: a brand-new user
/// hasn't formed an opinion yet, and the OS review sheet is a scarce
/// resource (iOS silently caps it to ~3 requests/year regardless of how
/// often the app asks). [_kThreshold] meals is "used it enough to have a
/// view", and [_kRequestedKey] makes the app-side ask a one-shot per
/// install so it never re-triggers after the threshold is crossed once.
class ReviewPromptStore {
  static const _kMealCountKey = 'review_prompt_meal_count';
  static const _kRequestedKey = 'review_prompt_requested';
  static const _kThreshold = 3;

  final SharedPreferences _prefs;

  const ReviewPromptStore(this._prefs);

  /// Call once per successful meal save. Returns true the first time the
  /// running count reaches [_kThreshold] and no request has been made yet —
  /// i.e. exactly when the caller should trigger the OS review sheet.
  Future<bool> recordMealSavedAndShouldPrompt() async {
    if (_prefs.getBool(_kRequestedKey) ?? false) return false;
    final count = (_prefs.getInt(_kMealCountKey) ?? 0) + 1;
    await _prefs.setInt(_kMealCountKey, count);
    return count >= _kThreshold;
  }

  Future<void> markRequested() async {
    await _prefs.setBool(_kRequestedKey, true);
  }
}

final reviewPromptStoreProvider = Provider<ReviewPromptStore>((ref) {
  return ReviewPromptStore(ref.watch(sharedPreferencesProvider));
});
