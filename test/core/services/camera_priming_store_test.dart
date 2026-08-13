import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/services/camera_priming_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _containerOver(SharedPreferences prefs) {
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

  group('CameraPrimingStore', () {
    test('a fresh install needs the rationale', () {
      final store = _containerOver(prefs).read(cameraPrimingStoreProvider);
      expect(store.needsRationale, isTrue);
    });

    test('a working camera settles the question for good', () async {
      final store = _containerOver(prefs).read(cameraPrimingStoreProvider);

      await store.markCameraWorked();

      expect(store.needsRationale, isFalse);
    });

    test('survives a restart', () async {
      await _containerOver(prefs).read(cameraPrimingStoreProvider)
          .markCameraWorked();

      // Same prefs, new container = relaunch.
      final store = _containerOver(prefs).read(cameraPrimingStoreProvider);

      expect(store.needsRationale, isFalse);
    });

    test('REGRESSION: a denial does NOT settle it — the explanation is the '
        'user\'s way back', () async {
      // Deliberately keyed on the camera working rather than the sheet being
      // shown. Someone who declines sees it again next visit; on Android the
      // OS dialog is effectively one-shot, so the in-app explanation is the
      // only re-entry point they have that does not involve Settings.
      final store = _containerOver(prefs).read(cameraPrimingStoreProvider);

      // Nothing marks a denial — the flag is simply never set.
      expect(store.needsRationale, isTrue);

      await store.markCameraWorked();
      expect(store.needsRationale, isFalse);
    });

    test('marking twice is harmless', () async {
      final store = _containerOver(prefs).read(cameraPrimingStoreProvider);

      await store.markCameraWorked();
      await store.markCameraWorked();

      expect(store.needsRationale, isFalse);
    });
  });
}
