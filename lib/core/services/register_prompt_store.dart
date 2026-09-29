import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/locale_provider.dart' show sharedPreferencesProvider;

/// Remembers whether a guest has already been offered an account after a
/// meal save. Offered once per install: repeating it after a "not now" turns
/// a value moment into nagging.
class RegisterPromptStore {
  static const _kShownKey = 'guest_register_prompt_shown_v1';

  final SharedPreferences _prefs;

  const RegisterPromptStore(this._prefs);

  bool get shouldPrompt => !(_prefs.getBool(_kShownKey) ?? false);

  Future<void> markShown() => _prefs.setBool(_kShownKey, true);
}

final registerPromptStoreProvider = Provider<RegisterPromptStore>((ref) {
  return RegisterPromptStore(ref.watch(sharedPreferencesProvider));
});
