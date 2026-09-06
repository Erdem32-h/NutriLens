/// Storage folders are virtual entries (id == null), not removable objects.
/// Bound all listings and reject unchanged pages rather than loop forever.
class StorageFolderCleaner {
  const StorageFolderCleaner({required this.list, required this.remove});

  final Future<List<StorageCleanupEntry>> Function(String path) list;
  final Future<void> Function(List<String> paths) remove;

  Future<void> clean(String root, {int maxListings = 1000}) async {
    var listings = 0;
    final completedFolders = <String>{};
    final activeFolders = <String>{};

    Future<void> visit(String folder) async {
      if (!activeFolders.add(folder)) throw StateError('Cyclic storage folder');
      Set<String> previousFiles = {};
      while (true) {
        if (++listings > maxListings) {
          throw StateError('Storage cleanup limit reached; retry deletion');
        }
        final entries = await list(folder);
        if (entries.isEmpty) break;
        final files = <String>{};
        for (final entry in entries) {
          if (entry.name.isEmpty ||
              entry.name == '.' ||
              entry.name == '..' ||
              entry.name.contains('/') ||
              entry.name.contains('\\')) {
            throw StateError('Invalid storage entry');
          }
          final path = '$folder/${entry.name}';
          if (entry.isFolder) {
            if (completedFolders.contains(path)) {
              throw StateError('Storage folder remains after cleanup');
            }
            await visit(path);
            completedFolders.add(path);
          } else {
            files.add(path);
          }
        }
        if (files.intersection(previousFiles).isNotEmpty) {
          throw StateError('Storage deletion made no progress; retry deletion');
        }
        if (files.isNotEmpty) await remove(files.toList());
        previousFiles = files;
      }
      activeFolders.remove(folder);
    }

    await visit(root);
  }
}

class StorageCleanupEntry {
  const StorageCleanupEntry(this.name, {required this.isFolder});
  final String name;
  final bool isFolder;
}
