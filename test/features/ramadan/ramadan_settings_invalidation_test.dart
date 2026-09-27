// Mirrors water_settings_invalidation_test.dart: profile_screen.dart's
// "delete my data" / account deletion handlers must invalidate
// ramadanSettingsProvider (and fastingDaysProvider) after clearing
// SharedPreferences, otherwise the enabled switch/location survive a
// deletion the user just asked for. This isolates the part that matters:
// once the store keys are gone, invalidating the provider must make it
// read the fresh (default) state rather than the cached Notifier state.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/features/ramadan/data/ramadan_settings_store.dart';
import 'package:nutrilens/features/ramadan/presentation/providers/ramadan_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('veri silindikten sonra ramadanSettingsProvider invalidate edilince '
      'enabled false ve location null okunur', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(ramadanSettingsProvider.notifier).setEnabled(true);
    await container
        .read(ramadanSettingsProvider.notifier)
        .setLocation(lat: 41.0, lng: 29.0, label: 'İstanbul');
    expect(container.read(ramadanSettingsProvider).enabled, isTrue);
    expect(container.read(ramadanSettingsProvider).location, isNotNull);

    // Account/data deletion clears every Ramadan preference key.
    for (final key in RamadanSettingsStore.keys) {
      await prefs.remove(key);
    }
    container.invalidate(ramadanSettingsProvider);

    expect(container.read(ramadanSettingsProvider).enabled, isFalse);
    expect(container.read(ramadanSettingsProvider).location, isNull);
  });
}
