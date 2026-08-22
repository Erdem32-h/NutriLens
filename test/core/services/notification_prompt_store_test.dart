import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/notification_prompt_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ilk cagride sorulmali', () async {
    final store = NotificationPromptStore(
      await SharedPreferences.getInstance(),
    );
    expect(await store.shouldPrompt(), isTrue);
  });

  test('sorulduktan sonra bir daha sorulmaz', () async {
    final store = NotificationPromptStore(
      await SharedPreferences.getInstance(),
    );
    await store.markAsked();
    expect(await store.shouldPrompt(), isFalse);
  });
}
