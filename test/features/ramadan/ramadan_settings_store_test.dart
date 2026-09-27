import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/ramadan/data/ramadan_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late RamadanSettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = RamadanSettingsStore(await SharedPreferences.getInstance());
  });

  test(
    'varsayilanlar: mod kapali, konum yok, sahur ofseti 45, teklif reddedilmemis',
    () {
      expect(store.enabled, isFalse);
      expect(store.location, isNull);
      expect(store.sahurOffsetMin, 45);
      expect(store.offerDismissedYear, isNull);
    },
  );

  test('setLocation sonrasi ucu de eslesir, plate GPS icin null olabilir', () async {
    await store.setLocation(lat: 39.9, lng: 32.8, label: 'Ankara', plate: 6);
    expect(store.location, (lat: 39.9, lng: 32.8, label: 'Ankara', plate: 6));

    await store.setLocation(lat: 41.0, lng: 29.0, label: 'Konumum');
    expect(store.location, (lat: 41.0, lng: 29.0, label: 'Konumum', plate: null));
  });

  test('setEnabled ve setSahurOffsetMin kalici', () async {
    await store.setEnabled(true);
    await store.setSahurOffsetMin(30);
    expect(store.enabled, isTrue);
    expect(store.sahurOffsetMin, 30);
  });

  test('dismissOffer yili kaydeder', () async {
    await store.dismissOffer(2027);
    expect(store.offerDismissedYear, 2027);
  });

  test('keys tum ramadan tercihlerini listeler', () {
    expect(RamadanSettingsStore.keys, [
      'ramadan_enabled',
      'ramadan_location_plate',
      'ramadan_location_lat',
      'ramadan_location_lng',
      'ramadan_location_label',
      'ramadan_sahur_offset_min',
      'ramadan_offer_dismissed_year',
    ]);
  });
}
