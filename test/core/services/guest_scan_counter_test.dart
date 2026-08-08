import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/services/guest_scan_counter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _containerOver(SharedPreferences prefs) async {
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('GuestScanCounter server baseline', () {
    test('is absent on a fresh install', () async {
      final container = await _containerOver(prefs);
      final counter = container.read(guestScanCounterProvider.notifier);

      expect(counter.hasServerBaseline, isFalse);
      expect(counter.count, 0);
    });

    test('is recorded even when the server count matches what we already '
        'had', () async {
      final container = await _containerOver(prefs);
      final counter = container.read(guestScanCounterProvider.notifier);

      // syncFromServer returns early when the server count is not higher.
      // The baseline must be set before that return — hearing from the
      // server at all is what makes the local counter trustworthy, not
      // whether the number changed.
      await counter.syncFromServer(0);

      expect(counter.hasServerBaseline, isTrue);
      expect(counter.count, 0);
    });

    test('survives a restart', () async {
      final first = await _containerOver(prefs);
      await first.read(guestScanCounterProvider.notifier).syncFromServer(2);

      // Same SharedPreferences, brand-new provider container = relaunch.
      final second = await _containerOver(prefs);
      final counter = second.read(guestScanCounterProvider.notifier);

      expect(counter.hasServerBaseline, isTrue);
      expect(counter.count, 2);
    });

    test('REGRESSION: an app-data clear takes the baseline with it', () async {
      final first = await _containerOver(prefs);
      await first.read(guestScanCounterProvider.notifier).syncFromServer(5);
      expect(
        first.read(guestScanCounterProvider.notifier).hasServerBaseline,
        isTrue,
      );

      // What `pm clear` (or "Clear data" in Settings) leaves behind.
      SharedPreferences.setMockInitialValues({});
      final wiped = await SharedPreferences.getInstance();
      final after = await _containerOver(wiped);
      final counter = after.read(guestScanCounterProvider.notifier);

      // The count resetting to 0 is the abuse. The baseline resetting with
      // it is what makes that harmless: with no baseline the gate refuses
      // to spend from this counter until the server has been heard from,
      // and the server remembers the device by hash.
      expect(counter.count, 0);
      expect(counter.hasServerBaseline, isFalse);
    });

    test('the courtesy scan is available once and survives a restart '
        'as spent', () async {
      final first = await _containerOver(prefs);
      final counter = first.read(guestScanCounterProvider.notifier);
      expect(counter.goodwillAvailable, isTrue);

      await counter.spendGoodwill();
      expect(counter.goodwillAvailable, isFalse);

      final second = await _containerOver(prefs);
      expect(
        second.read(guestScanCounterProvider.notifier).goodwillAvailable,
        isFalse,
      );
    });

    test('spending the courtesy scan does not touch the server-mirrored '
        'count', () async {
      final container = await _containerOver(prefs);
      final counter = container.read(guestScanCounterProvider.notifier);
      await counter.syncFromServer(2);

      await counter.spendGoodwill();

      // The count mirrors the server. Letting courtesy write to it would
      // make an unauthorised scan look server-granted on the next sync.
      expect(counter.count, 2);
    });

    test('reset() clears the baseline and the courtesy scan along with '
        'the count', () async {
      final container = await _containerOver(prefs);
      final counter = container.read(guestScanCounterProvider.notifier);
      await counter.syncFromServer(3);
      await counter.spendGoodwill();

      await counter.reset();

      expect(counter.count, 0);
      expect(counter.hasServerBaseline, isFalse);
      expect(counter.goodwillAvailable, isTrue);
    });
  });

  group('GuestScanCounter budget', () {
    test('syncFromServer only ever raises the count', () async {
      final container = await _containerOver(prefs);
      final counter = container.read(guestScanCounterProvider.notifier);

      await counter.syncFromServer(4);
      await counter.syncFromServer(1);

      expect(counter.count, 4);
    });

    test('syncFromServer clamps to the lifetime limit', () async {
      final container = await _containerOver(prefs);
      final counter = container.read(guestScanCounterProvider.notifier);

      await counter.syncFromServer(99);

      expect(counter.count, GuestScanCounter.lifetimeLimit);
      expect(counter.canScan, isFalse);
      expect(counter.remaining, 0);
    });
  });
}
