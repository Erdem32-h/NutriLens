import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/fasting/data/fasting_settings_store.dart';
import 'package:nutrilens/features/fasting/domain/fasting_protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FastingSettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = FastingSettingsStore(await SharedPreferences.getInstance());
  });

  test('varsayilan protokol 16:8', () {
    expect(store.protocol, FastingProtocol.p16_8);
  });

  test('setProtocol sonra protocol degistirileni doner (round-trip)', () async {
    await store.setProtocol(FastingProtocol.omad);
    expect(store.protocol, FastingProtocol.omad);
  });
}
