import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/features/product/presentation/providers/compare_hint_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith({
  Map<String, Object> prefs = const {},
  bool withPreferences = true,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      if (withPreferences)
        sharedPreferencesProvider.overrideWithValue(instance),
    ],
  );
}

void main() {
  test('taze kurulumda false döner (şerit görünür)', () async {
    final container = await containerWith();
    addTearDown(container.dispose);
    expect(container.read(compareHintDismissedProvider), isFalse);
  });

  test('flag yazılmışsa true döner (şerit gizli)', () async {
    final container =
        await containerWith(prefs: {kCompareHintDismissedKey: true});
    addTearDown(container.dispose);
    expect(container.read(compareHintDismissedProvider), isTrue);
  });

  test('prefs erişilemezse true döner (savunmacı: ipucu gösterilmez)',
      () async {
    final container = await containerWith(withPreferences: false);
    addTearDown(container.dispose);
    expect(container.read(compareHintDismissedProvider), isTrue);
  });
}
