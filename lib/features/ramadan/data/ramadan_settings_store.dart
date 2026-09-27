import 'package:shared_preferences/shared_preferences.dart';

/// Device-global Ramadan preferences. Cleared on "delete my data" together
/// with water and health filters (see `UserDataDeletionService`).
class RamadanSettingsStore {
  static const _enabledKey = 'ramadan_enabled';
  static const _plateKey = 'ramadan_location_plate';
  static const _latKey = 'ramadan_location_lat';
  static const _lngKey = 'ramadan_location_lng';
  static const _labelKey = 'ramadan_location_label';
  static const _sahurOffsetKey = 'ramadan_sahur_offset_min';
  static const _offerDismissedYearKey = 'ramadan_offer_dismissed_year';

  static const keys = [
    _enabledKey,
    _plateKey,
    _latKey,
    _lngKey,
    _labelKey,
    _sahurOffsetKey,
    _offerDismissedYearKey,
  ];

  final SharedPreferences _prefs;

  const RamadanSettingsStore(this._prefs);

  bool get enabled => _prefs.getBool(_enabledKey) ?? false;

  Future<void> setEnabled(bool enabled) =>
      _prefs.setBool(_enabledKey, enabled);

  /// Null unless lat, lng and label are all present. `plate` alone is
  /// nullable within a set location — null means the coordinates came from
  /// GPS rather than a chosen province.
  ({double lat, double lng, String label, int? plate})? get location {
    final lat = _prefs.getDouble(_latKey);
    final lng = _prefs.getDouble(_lngKey);
    final label = _prefs.getString(_labelKey);
    if (lat == null || lng == null || label == null) return null;
    return (lat: lat, lng: lng, label: label, plate: _prefs.getInt(_plateKey));
  }

  Future<void> setLocation({
    required double lat,
    required double lng,
    required String label,
    int? plate,
  }) async {
    await _prefs.setDouble(_latKey, lat);
    await _prefs.setDouble(_lngKey, lng);
    await _prefs.setString(_labelKey, label);
    if (plate == null) {
      await _prefs.remove(_plateKey);
    } else {
      await _prefs.setInt(_plateKey, plate);
    }
  }

  int get sahurOffsetMin => _prefs.getInt(_sahurOffsetKey) ?? 45;

  Future<void> setSahurOffsetMin(int minutes) =>
      _prefs.setInt(_sahurOffsetKey, minutes);

  int? get offerDismissedYear => _prefs.getInt(_offerDismissedYearKey);

  Future<void> dismissOffer(int year) =>
      _prefs.setInt(_offerDismissedYearKey, year);
}
