import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/metrics_prompt_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ilk cagride sorulmali', () async {
    final store = MetricsPromptStore(await SharedPreferences.getInstance());
    expect(await store.shouldPrompt(), isTrue);
  });

  test('reddedildikten sonra bir daha sorulmaz', () async {
    final store = MetricsPromptStore(await SharedPreferences.getInstance());
    await store.markDismissed();
    expect(await store.shouldPrompt(), isFalse);
  });

  test('tamamlandiktan sonra bir daha sorulmaz', () async {
    final store = MetricsPromptStore(await SharedPreferences.getInstance());
    await store.markCompleted();
    expect(await store.shouldPrompt(), isFalse);
  });
}
