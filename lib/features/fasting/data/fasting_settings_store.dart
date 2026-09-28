import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fasting_protocol.dart';

/// Device-global intermittent fasting preferences. Cleared on "delete my
/// data" together with water and Ramadan settings (see
/// `UserDataDeletionService`).
class FastingSettingsStore {
  static const _protocolKey = 'if_protocol';

  static const keys = [_protocolKey];

  final SharedPreferences _prefs;

  const FastingSettingsStore(this._prefs);

  /// Defaults to 16:8 when nothing is stored yet.
  FastingProtocol get protocol =>
      FastingProtocol.fromLabel(_prefs.getString(_protocolKey));

  Future<void> setProtocol(FastingProtocol protocol) =>
      _prefs.setString(_protocolKey, protocol.label);
}
