import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/locale_provider.dart' show sharedPreferencesProvider;

/// Remembers whether the ölçüm (metrics) wizard has been "settled" — either
/// completed or explicitly dismissed — on this install.
///
/// Deliberately a single flag rather than separate dismissed/completed
/// flags: once the user has answered the question once, in either
/// direction, [MetricsWizardScreen] must never open itself again. "Şimdi
/// değil" is permanent, same contract as the camera priming sheet — the
/// user's own account/profile entry point (Task 8) is the only way back in
/// after a dismissal, not another automatic prompt.
class MetricsPromptStore {
  static const _kSettledKey = 'metrics_prompt_settled';

  final SharedPreferences _prefs;

  const MetricsPromptStore(this._prefs);

  /// True until the wizard has been completed or dismissed at least once.
  Future<bool> shouldPrompt() async {
    return !(_prefs.getBool(_kSettledKey) ?? false);
  }

  Future<void> markDismissed() async {
    await _prefs.setBool(_kSettledKey, true);
  }

  Future<void> markCompleted() async {
    await _prefs.setBool(_kSettledKey, true);
  }
}

final metricsPromptStoreProvider = Provider<MetricsPromptStore>((ref) {
  return MetricsPromptStore(ref.watch(sharedPreferencesProvider));
});
