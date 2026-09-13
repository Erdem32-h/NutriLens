import 'package:shared_preferences/shared_preferences.dart';

import '../domain/water_goal.dart';

/// Device-global water preferences. Cleared on "delete my data" together
/// with health filters (see `UserDataDeletionService`).
class WaterSettingsStore {
  static const _goalKey = 'water_goal_glasses';
  static const _reminderKey = 'water_reminder_enabled';
  static const _promptShownKey = 'water_reminder_prompt_shown';
  static const keys = [_goalKey, _reminderKey, _promptShownKey];

  final SharedPreferences _prefs;

  const WaterSettingsStore(this._prefs);

  /// Null → no manual goal; the weight-based suggestion applies.
  int? get goal => _prefs.getInt(_goalKey);

  Future<void> setGoal(int glasses) =>
      _prefs.setInt(_goalKey, glasses.clamp(kMinGoalGlasses, kMaxGoalGlasses));

  bool get reminderEnabled => _prefs.getBool(_reminderKey) ?? false;

  Future<void> setReminderEnabled(bool enabled) =>
      _prefs.setBool(_reminderKey, enabled);

  bool get promptShown => _prefs.getBool(_promptShownKey) ?? false;

  Future<void> markPromptShown() => _prefs.setBool(_promptShownKey, true);
}
