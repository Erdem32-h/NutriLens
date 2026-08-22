import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/review_prompt_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('esik altinda sorulmaz', () async {
    final store = ReviewPromptStore(await SharedPreferences.getInstance());
    expect(await store.recordMealSavedAndShouldPrompt(), isFalse);
    expect(await store.recordMealSavedAndShouldPrompt(), isFalse);
  });

  test('esige ulasinca sorulur', () async {
    final store = ReviewPromptStore(await SharedPreferences.getInstance());
    await store.recordMealSavedAndShouldPrompt();
    await store.recordMealSavedAndShouldPrompt();
    expect(await store.recordMealSavedAndShouldPrompt(), isTrue);
  });

  test('istendikten sonra bir daha sorulmaz', () async {
    final store = ReviewPromptStore(await SharedPreferences.getInstance());
    await store.recordMealSavedAndShouldPrompt();
    await store.recordMealSavedAndShouldPrompt();
    await store.recordMealSavedAndShouldPrompt();
    await store.markRequested();
    expect(await store.recordMealSavedAndShouldPrompt(), isFalse);
  });

  test('istek verilmeden esik gecilirse tekrar sorulmaya devam eder', () async {
    final store = ReviewPromptStore(await SharedPreferences.getInstance());
    await store.recordMealSavedAndShouldPrompt();
    await store.recordMealSavedAndShouldPrompt();
    expect(await store.recordMealSavedAndShouldPrompt(), isTrue);
    // markRequested() cagrilmadi (OS API mevcut degildi senaryosu) —
    // sonraki kayitta tekrar true donmeli.
    expect(await store.recordMealSavedAndShouldPrompt(), isTrue);
  });
}
