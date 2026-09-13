// F1 regression: profile_screen.dart's "delete my data" / account deletion
// handlers must invalidate waterSettingsProvider (and waterToday/waterWeek)
// after clearing SharedPreferences, otherwise the switch/goal/reminders
// survive a deletion the user just asked for. This test isolates the part
// that actually matters: once the store keys are gone, invalidating the
// provider must make it read the fresh (default) state rather than the
// cached Notifier state.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/features/water/data/water_settings_store.dart';
import 'package:nutrilens/features/water/presentation/providers/water_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('veri silindikten sonra waterSettingsProvider invalidate edilince '
      'reminderEnabled false okunur', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(waterSettingsProvider.notifier)
        .setReminderEnabled(true);
    await container.read(waterSettingsProvider.notifier).setGoal(15);
    expect(container.read(waterSettingsProvider).reminderEnabled, isTrue);
    expect(container.read(waterSettingsProvider).customGoal, 15);

    // Account/data deletion clears every water preference key.
    for (final key in WaterSettingsStore.keys) {
      await prefs.remove(key);
    }
    container.invalidate(waterSettingsProvider);

    expect(container.read(waterSettingsProvider).reminderEnabled, isFalse);
    expect(container.read(waterSettingsProvider).customGoal, isNull);
  });
}
