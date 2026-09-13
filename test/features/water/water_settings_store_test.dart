import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/water/data/water_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late WaterSettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = WaterSettingsStore(await SharedPreferences.getInstance());
  });

  test('varsayilanlar: hedef yok, hatirlatma kapali, soru sorulmadi', () {
    expect(store.goal, isNull);
    expect(store.reminderEnabled, isFalse);
    expect(store.promptShown, isFalse);
  });

  test('hedef 1-20 araligina sikistirilarak kaydedilir', () async {
    await store.setGoal(25);
    expect(store.goal, 20);
    await store.setGoal(0);
    expect(store.goal, 1);
  });

  test('hatirlatma ve soru bayragi kalici', () async {
    await store.setReminderEnabled(true);
    await store.markPromptShown();
    expect(store.reminderEnabled, isTrue);
    expect(store.promptShown, isTrue);
  });

  test('keys tum su tercihlerini listeler', () {
    expect(WaterSettingsStore.keys, [
      'water_goal_glasses',
      'water_reminder_enabled',
      'water_reminder_prompt_shown',
    ]);
  });
}
