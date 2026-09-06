import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/profile/data/services/storage_folder_cleaner.dart';

void main() {
  test(
    'removes all pages and nested folders without skipping objects',
    () async {
      final files = {
        for (var i = 0; i < 205; i++) 'user/$i.jpg',
        'user/nested/meal.jpg',
        'other/keep.jpg',
      };
      final cleaner = StorageFolderCleaner(
        list: (folder) async {
          final entries = <String, StorageCleanupEntry>{};
          for (final file in files.where((p) => p.startsWith('$folder/'))) {
            final relative = file.substring(folder.length + 1);
            final name = relative.split('/').first;
            entries[name] = StorageCleanupEntry(
              name,
              isFolder: relative.contains('/'),
            );
          }
          return entries.values.take(100).toList();
        },
        remove: (paths) async => files.removeAll(paths),
      );
      await cleaner.clean('user');
      expect(files, {'other/keep.jpg'});
    },
  );

  test('fails promptly if storage keeps returning a deleted file', () async {
    var calls = 0;
    final cleaner = StorageFolderCleaner(
      list: (_) async {
        calls++;
        return [const StorageCleanupEntry('meal.jpg', isFolder: false)];
      },
      remove: (_) async {},
    );
    await expectLater(cleaner.clean('user'), throwsStateError);
    expect(calls, 2);
  });

  test(
    'persistent empty folder placeholder cannot cause an infinite loop',
    () async {
      var calls = 0;
      final cleaner = StorageFolderCleaner(
        list: (path) async {
          calls++;
          return path == 'user'
              ? [const StorageCleanupEntry('nested', isFolder: true)]
              : [];
        },
        remove: (_) async => fail('Folders must not be sent to remove'),
      );
      await expectLater(cleaner.clean('user'), throwsStateError);
      expect(calls, 3);
    },
  );

  test('bounds work when files keep arriving', () async {
    var calls = 0;
    final cleaner = StorageFolderCleaner(
      list: (_) async => [
        StorageCleanupEntry('${calls++}.jpg', isFolder: false),
      ],
      remove: (_) async {},
    );
    await expectLater(cleaner.clean('user', maxListings: 3), throwsStateError);
    expect(calls, 3);
  });

  test('rejects path traversal before removal', () async {
    final cleaner = StorageFolderCleaner(
      list: (_) async => [
        const StorageCleanupEntry('../other.jpg', isFolder: false),
      ],
      remove: (_) async => fail('Unsafe path was removed'),
    );
    await expectLater(cleaner.clean('user'), throwsStateError);
  });
}
