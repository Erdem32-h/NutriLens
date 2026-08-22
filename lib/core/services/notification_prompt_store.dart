import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/locale_provider.dart' show sharedPreferencesProvider;

/// Remembers whether the OS notification-permission ask has already fired
/// on this install. The ask happens exactly once, right after the first
/// meal save — asking earlier (before the user has seen any value) or
/// repeatedly would just burn the OS's own one-shot permission dialog for
/// nothing.
class NotificationPromptStore {
  static const _kAskedKey = 'notification_permission_asked';

  final SharedPreferences _prefs;

  const NotificationPromptStore(this._prefs);

  Future<bool> shouldPrompt() async {
    return !(_prefs.getBool(_kAskedKey) ?? false);
  }

  Future<void> markAsked() async {
    await _prefs.setBool(_kAskedKey, true);
  }
}

final notificationPromptStoreProvider = Provider<NotificationPromptStore>((
  ref,
) {
  return NotificationPromptStore(ref.watch(sharedPreferencesProvider));
});
